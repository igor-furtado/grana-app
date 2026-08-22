import { createClient } from "npm:@supabase/supabase-js@2";

type CategorizationRequest = {
  taxonomy_version: number;
  items: Array<{
    index: number;
    description: string;
    sign: "income" | "expense" | "unknown";
    account_context: string;
    source_hint?: string | null;
  }>;
  categories: Array<{
    id: string;
    slug: string;
    name: string;
    kind: "expense" | "income" | "transfer";
    subcategories: Array<{
      id: string;
      name: string;
    }>;
  }>;
  own_accounts: Array<{
    name: string;
    type_display: string;
    institution_name?: string | null;
  }>;
};

type CategorizationResult = {
  index: number;
  description_hash: string;
  normalized_description: string;
  category_slug: string;
  subcategory_name: string | null;
  confidence: number;
  source: "cache" | "ai" | "fallback";
};

type RuntimeConfig = {
  provider: string;
  model: string;
};

type FewShotExample = {
  normalized_description: string;
  corrected_category_slug: string;
  corrected_subcategory_name: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ code: "missing_authorization" }, 401);
    }

    const userClient = createClient(
      requireEnv("SUPABASE_URL"),
      requireEnv("SUPABASE_ANON_KEY"),
      {
        global: {
          headers: {
            Authorization: authHeader,
          },
        },
      },
    );
    const adminClient = createClient(
      requireEnv("SUPABASE_URL"),
      requireEnv("SUPABASE_SERVICE_ROLE_KEY"),
    );

    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser(token);
    if (userError || !user) {
      return jsonResponse({ code: "invalid_user_jwt" }, 401);
    }

    const body = (await request.json()) as CategorizationRequest;
    const taxonomy = buildTaxonomy(body.categories);
    const runtimeConfig = await resolveRuntimeConfig(adminClient, user.id);
    const preparedItems = await Promise.all(
      body.items.map(async (item) => {
        const normalizedDescription = pseudonymizeDescription(item.description);
        return {
          ...item,
          normalized_description: normalizedDescription,
          description_hash: await descriptionHash(
            normalizedDescription,
            item.account_context,
            item.sign,
            body.taxonomy_version,
          ),
        };
      }),
    );

    const cachedResults = await lookupCache(
      userClient,
      taxonomy,
      preparedItems,
      runtimeConfig.model,
    );
    const fewShots = await loadFewShots(userClient, taxonomy);

    const misses = preparedItems.filter((item) => !cachedResults.has(item.index));
    const aiResults = misses.length === 0
      ? []
      : await classifyWithOpenAI({
        request: body,
        misses,
        fewShots,
        runtimeConfig,
      });

    const results = preparedItems.map((item) =>
      cachedResults.get(item.index) ?? aiResults.find((result) => result.index === item.index) ?? {
        index: item.index,
        description_hash: item.description_hash,
        normalized_description: item.normalized_description,
        category_slug: "nao-classificado",
        subcategory_name: null,
        confidence: 0,
        source: "fallback",
      }
    );

    return jsonResponse({
      results,
      metadata: {
        provider: runtimeConfig.provider,
        model: runtimeConfig.model,
        from_cache: cachedResults.size,
        from_ai: aiResults.length,
        fallback_count: results.filter((result) => result.category_slug === "nao-classificado").length,
      },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "unexpected_error";
    return jsonResponse({ code: message }, 500);
  }
});

function buildTaxonomy(categories: CategorizationRequest["categories"]) {
  const rootsById = new Map<string, CategorizationRequest["categories"][number]>();
  const rootsBySlug = new Map<string, CategorizationRequest["categories"][number]>();

  for (const category of categories) {
    rootsById.set(category.id, category);
    rootsBySlug.set(category.slug, category);
  }

  return {
    rootsById,
    rootsBySlug,
    resolveCache(categoryId: string, subcategoryId: string | null) {
      const root = rootsById.get(categoryId);
      if (!root) return null;
      const subcategory = subcategoryId
        ? root.subcategories.find((entry) => entry.id === subcategoryId) ?? null
        : null;
      return {
        category_slug: root.slug,
        subcategory_name: subcategory?.name ?? null,
      };
    },
    resolveCorrection(categoryId: string, subcategoryId: string | null): FewShotExample | null {
      const resolved = this.resolveCache(categoryId, subcategoryId);
      if (!resolved) return null;
      return {
        normalized_description: "",
        corrected_category_slug: resolved.category_slug,
        corrected_subcategory_name: resolved.subcategory_name,
      };
    },
  };
}

async function resolveRuntimeConfig(
  adminClient: ReturnType<typeof createClient>,
  userId: string,
): Promise<RuntimeConfig> {
  const { data, error } = await adminClient.schema("api").rpc(
    "v1_resolve_categorization_runtime_config",
    { target_user_id: userId },
  );
  if (error) throw error;
  const row = Array.isArray(data) ? data[0] : data;
  if (!row?.provider || !row?.model) {
    throw new Error("missing_runtime_config");
  }
  return {
    provider: row.provider,
    model: row.model,
  };
}

async function lookupCache(
  userClient: ReturnType<typeof createClient>,
  taxonomy: ReturnType<typeof buildTaxonomy>,
  items: Array<{
    index: number;
    description_hash: string;
    normalized_description: string;
  }>,
  model: string,
): Promise<Map<number, CategorizationResult>> {
  const uniqueHashes = [...new Set(items.map((item) => item.description_hash))];
  const { data, error } = await userClient.schema("api").rpc(
    "v1_lookup_categorization_cache",
    {
      p_description_hashes: uniqueHashes,
      p_model: model,
    },
  );
  if (error) throw error;

  const byHash = new Map<string, CategorizationResult>();
  for (const row of data ?? []) {
    const resolved = taxonomy.resolveCache(row.category_id, row.subcategory_id);
    if (!resolved) continue;
    byHash.set(row.description_hash, {
      index: -1,
      description_hash: row.description_hash,
      normalized_description: "",
      category_slug: resolved.category_slug,
      subcategory_name: resolved.subcategory_name,
      confidence: clampConfidence(row.confidence),
      source: "cache",
    });
  }

  const byIndex = new Map<number, CategorizationResult>();
  items.forEach((item) => {
    const cached = byHash.get(item.description_hash);
    if (!cached) return;
    byIndex.set(item.index, {
      ...cached,
      index: item.index,
      description_hash: item.description_hash,
      normalized_description: item.normalized_description,
    });
  });
  return byIndex;
}

async function loadFewShots(
  userClient: ReturnType<typeof createClient>,
  taxonomy: ReturnType<typeof buildTaxonomy>,
): Promise<FewShotExample[]> {
  const { data, error } = await userClient.schema("api").rpc(
    "v1_list_categorization_few_shots",
    { p_limit: 10 },
  );
  if (error) throw error;

  return (data ?? []).flatMap((row) => {
    const resolved = taxonomy.resolveCorrection(
      row.corrected_category_id,
      row.corrected_subcategory_id,
    );
    if (!resolved) return [];
    return [{
      normalized_description: row.normalized_description,
      corrected_category_slug: resolved.corrected_category_slug,
      corrected_subcategory_name: resolved.corrected_subcategory_name,
    }];
  });
}

async function classifyWithOpenAI(args: {
  request: CategorizationRequest;
  misses: Array<CategorizationRequest["items"][number] & {
    normalized_description: string;
    description_hash: string;
  }>;
  fewShots: FewShotExample[];
  runtimeConfig: RuntimeConfig;
}): Promise<CategorizationResult[]> {
  if (args.runtimeConfig.provider !== "openai") {
    throw new Error(`unsupported_provider:${args.runtimeConfig.provider}`);
  }

  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${requireEnv("OPENAI_API_KEY")}`,
    },
    body: JSON.stringify({
      model: args.runtimeConfig.model,
      messages: [
        {
          role: "system",
          content:
            "Você classifica transações financeiras brasileiras. Responda só com JSON válido. Use apenas category_slug e subcategory_name presentes na taxonomia enviada. Se estiver inseguro, use a raiz 'nao-classificado' e confidence baixa. Transferências entre contas próprias só devem usar a raiz 'transferencias'.",
        },
        {
          role: "user",
          content: JSON.stringify({
            taxonomy_version: args.request.taxonomy_version,
            items: args.misses.map((item) => ({
              index: item.index,
              description: item.normalized_description,
              sign: item.sign,
              account_context: item.account_context,
              source_hint: item.source_hint ?? null,
            })),
            categories: args.request.categories,
            own_accounts: args.request.own_accounts,
            few_shots: args.fewShots,
          }),
        },
      ],
      response_format: {
        type: "json_schema",
        json_schema: {
          name: "categorization_results",
          strict: true,
          schema: {
            type: "object",
            additionalProperties: false,
            properties: {
              results: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    index: { type: "integer" },
                    category_slug: { type: "string" },
                    subcategory_name: { type: ["string", "null"] },
                    confidence: { type: "number" },
                  },
                  required: ["index", "category_slug", "subcategory_name", "confidence"],
                },
              },
            },
            required: ["results"],
          },
        },
      },
    }),
  });
  if (!response.ok) {
    throw new Error(`openai_http_${response.status}`);
  }

  const payload = await response.json();
  const content = payload?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("openai_missing_content");
  }

  const decoded = JSON.parse(content) as { results: CategorizationResult[] };
  const missByIndex = new Map(args.misses.map((item) => [item.index, item]));
  return (decoded.results ?? []).map((result) => ({
    index: result.index,
    description_hash: missByIndex.get(result.index)?.description_hash ?? "",
    normalized_description: missByIndex.get(result.index)?.normalized_description ?? "",
    category_slug: result.category_slug,
    subcategory_name: result.subcategory_name ?? null,
    confidence: clampConfidence(result.confidence),
    source: "ai",
  }));
}

async function descriptionHash(
  normalizedDescription: string,
  accountContext: string,
  sign: string,
  taxonomyVersion: number,
) {
  const data = new TextEncoder().encode(
    `${normalizedDescription}|${accountContext}|${sign}|taxonomy-${taxonomyVersion}`,
  );
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function clampConfidence(value: number) {
  return Math.max(0, Math.min(1, Number.isFinite(value) ? value : 0));
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function pseudonymizeDescription(raw: string) {
  const folded = raw
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase();

  const withoutLongDigits = folded.replace(/\d{4,}/g, "");

  return withoutLongDigits
    .split(/\s+/)
    .filter(Boolean)
    .join(" ")
    .trim();
}

function requireEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`missing_env:${name}`);
  return value;
}

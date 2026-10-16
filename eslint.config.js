import js from "@eslint/js"
import { defineConfigWithVueTs, vueTsConfigs } from "@vue/eslint-config-typescript"
import pluginVue from "eslint-plugin-vue"
import globals from "globals"
import { globalIgnores } from "eslint/config"

export default defineConfigWithVueTs(
  globalIgnores(["dist", "legacy"]),
  {
    files: ["**/*.{js,mjs,ts,vue}"],
    languageOptions: {
      globals: globals.browser,
    },
  },
  js.configs.recommended,
  pluginVue.configs["flat/recommended"],
  vueTsConfigs.recommended,
  {
    rules: {
      "vue/html-self-closing": "off",
      "vue/html-indent": "off",
      "vue/max-attributes-per-line": "off",
      "vue/multi-word-component-names": "off",
      "vue/require-default-prop": "off",
      "vue/singleline-html-element-content-newline": "off",
    },
  },
)

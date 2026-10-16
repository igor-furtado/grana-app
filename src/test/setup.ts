import "@testing-library/jest-dom/vitest"
import { cleanup } from "@testing-library/vue"
import { afterEach } from "vitest"

afterEach(cleanup)

class ResizeObserverStub implements ResizeObserver {
  disconnect() {}
  observe() {}
  unobserve() {}
}

globalThis.ResizeObserver = ResizeObserverStub

Element.prototype.hasPointerCapture = () => false
Element.prototype.setPointerCapture = () => {}
Element.prototype.releasePointerCapture = () => {}

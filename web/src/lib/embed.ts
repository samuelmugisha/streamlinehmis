// True only inside the widget's expand iframe. Hosting wrappers that iframe the
// whole app (the Hugging Face Spaces page) are not the widget, so the standalone
// UI -- theme toggle included -- stays intact there.
const HOSTING_WRAPPERS = ['https://huggingface.co']

function parentOrigin(): string {
  const ancestors = window.location.ancestorOrigins
  if (ancestors && ancestors.length > 0) return ancestors[0]
  try {
    return document.referrer ? new URL(document.referrer).origin : ''
  } catch {
    return ''
  }
}

export const isEmbedded =
  typeof window !== 'undefined' &&
  window.self !== window.top &&
  !HOSTING_WRAPPERS.includes(parentOrigin())

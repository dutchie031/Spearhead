class CodeBlock extends HTMLElement {
    connectedCallback() {
        // Get the code content as text, preserving whitespace
        let code = this.textContent.replace(/\r\n?/g, "\n");
        // Remove leading/trailing blank lines
        code = code.replace(/^\s*\n/, '').replace(/\n\s*$/, '');
        // Find leading spaces from the first non-empty line
        const lines = code.split("\n");
        const firstLine = lines.find(line => line.trim().length > 0) || '';
        const leadingSpaces = firstLine.match(/^\s*/)[0].length;
        // Remove that many leading spaces from all lines
        const stripped = lines.map(line => line.slice(leadingSpaces)).join("\n");
        // Escape HTML special characters
        const escaped = stripped
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
        const lang = this.getAttribute('lang') || '';
        const langClass = lang ? `language-${lang}` : '';
        this.innerHTML = `<pre class=\"custom-code-block\"><code class=\"${langClass}\">${escaped}</code></pre>`;
        // If Prism or highlight.js is present, trigger highlighting
        if (window.Prism && Prism.highlightElement) {
            Prism.highlightElement(this.querySelector('code'));
        } else if (window.hljs && hljs.highlightElement) {
            hljs.highlightElement(this.querySelector('code'));
        }
    }
}
customElements.define('code-block', CodeBlock);

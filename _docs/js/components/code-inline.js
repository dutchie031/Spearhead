class CodeInline extends HTMLElement {
    connectedCallback() {
        // Get the code content as text
        let code = this.textContent;
        
        // Escape HTML special characters
        code = code
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
        
        // Highlight variables: $variable, {variable}, or %variable%
        code = code.replace(/(\$[a-zA-Z_][\w]*)|(\{[^\}]+\})|(%[^%]+%)/g, match =>
            `<span class="inline-var">${match}</span>`
        );
        
        // Get language attribute for potential syntax highlighting
        const lang = this.getAttribute('lang') || '';
        const langClass = lang ? `language-${lang}` : '';
        
        this.innerHTML = `<code class="custom-inline-code ${langClass}">${code}</code>`;
        
        // If Prism or highlight.js is present, trigger highlighting
        if (window.Prism && Prism.highlightElement) {
            Prism.highlightElement(this.querySelector('code'));
        } else if (window.hljs && hljs.highlightElement) {
            hljs.highlightElement(this.querySelector('code'));
        }
    }
}

customElements.define('code-inline', CodeInline);

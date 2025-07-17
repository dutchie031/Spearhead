class Note extends HTMLElement {
    connectedCallback() {
        // Get the note content
        const content = this.innerHTML;
        
        // Get optional type attribute for different note styles
        const type = this.getAttribute('type') || 'default';
        
        // Get optional title attribute
        const title = this.getAttribute('title');
        
        // Build the note HTML
        let noteHTML = '<div class="note';
        
        // Add type-specific class if provided
        if (type !== 'default') {
            noteHTML += ` note-${type}`;
        }
        
        noteHTML += '">';
        
        // Add title if provided
        if (title) {
            noteHTML += `<h4 class="note-title">${title}</h4>`;
        }
        
        // Add the content
        noteHTML += content;
        noteHTML += '</div>';
        
        this.innerHTML = noteHTML;
    }
}

customElements.define('note-box', Note);

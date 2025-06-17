class Sidebar extends HTMLElement {
    constructor() {
        super();
        this.navItems = [];
    }

    connectedCallback() {
        this.render();
        this.scanHeaders();
        this.setupScrollListener();
        this.highlightActiveSection();
    }

    scanHeaders() {
        // Clear existing nav items
        this.navItems = [];
        
        // Find all h2, h3, and h4 elements with IDs in the content area
        const contentWrapper = document.querySelector('.content-wrapper');
        if (!contentWrapper) return;

        const headers = contentWrapper.querySelectorAll('h2[id], h3[id], h4[id]');
        
        headers.forEach(header => {
            const id = header.getAttribute('id');
            const text = header.textContent.trim();
            const level = header.tagName.toLowerCase();
            
            this.navItems.push({
                id,
                text,
                level,
                element: header
            });
        });

        this.renderNavigation();
    }

    renderNavigation() {
        const ul = this.querySelector('ul');
        if (!ul) return;

        // Clear existing content
        ul.innerHTML = '';

        let currentH2Li = null;
        let currentH3Li = null;

        this.navItems.forEach(item => {
            if (item.level === 'h2') {
                // Create h2 item
                const li = document.createElement('li');
                const a = document.createElement('a');
                a.href = `#${item.id}`;
                a.className = 'side-nav-h2';
                a.textContent = item.text;
                a.addEventListener('click', (e) => this.handleNavClick(e, item.id));
                
                li.appendChild(a);
                ul.appendChild(li);
                currentH2Li = li;
                currentH3Li = null;
            } else if (item.level === 'h3' && currentH2Li) {
                // Create h3 item under current h2
                let subUl = currentH2Li.querySelector('ul');
                if (!subUl) {
                    subUl = document.createElement('ul');
                    currentH2Li.appendChild(subUl);
                }

                const li = document.createElement('li');
                const a = document.createElement('a');
                a.href = `#${item.id}`;
                a.className = 'side-nav-h3';
                a.textContent = item.text;
                a.addEventListener('click', (e) => this.handleNavClick(e, item.id));
                
                li.appendChild(a);
                subUl.appendChild(li);
                currentH3Li = li;
            } else if (item.level === 'h4' && currentH3Li) {
                // Create h4 item under current h3
                let subUl = currentH3Li.querySelector('ul');
                if (!subUl) {
                    subUl = document.createElement('ul');
                    currentH3Li.appendChild(subUl);
                }

                const li = document.createElement('li');
                const a = document.createElement('a');
                a.href = `#${item.id}`;
                a.className = 'side-nav-h4';
                a.textContent = item.text;
                a.addEventListener('click', (e) => this.handleNavClick(e, item.id));
                
                li.appendChild(a);
                subUl.appendChild(li);
            }
        });
    }

    handleNavClick(e, targetId) {
        e.preventDefault();
        
        // Remove active class from all links
        this.querySelectorAll('a').forEach(link => {
            link.classList.remove('active');
        });
        
        // Add active class to clicked link
        e.target.classList.add('active');
        
        // Smooth scroll to target
        const targetElement = document.getElementById(targetId);
        if (targetElement) {
            targetElement.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    }

    setupScrollListener() {
        let ticking = false;
        
        const handleScroll = () => {
            if (!ticking) {
                requestAnimationFrame(() => {
                    this.highlightActiveSection();
                    ticking = false;
                });
                ticking = true;
            }
        };

        window.addEventListener('scroll', handleScroll);
    }

    highlightActiveSection() {
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const offset = 100; // Offset for highlighting

        let activeId = '';
        
        // Find the currently visible section
        this.navItems.forEach(item => {
            const element = item.element;
            const rect = element.getBoundingClientRect();
            const elementTop = rect.top + scrollTop;
            
            if (elementTop <= scrollTop + offset) {
                activeId = item.id;
            }
        });

        // Update active state
        this.querySelectorAll('a').forEach(link => {
            link.classList.remove('active');
        });

        if (activeId !== nil && activeId !== '') {
            const activeLink = this.querySelector(`a[href="#${activeId}"]`);
            if (activeLink) {
                activeLink.classList.add('active');
            }
        }
    }

    render() {
        this.innerHTML = `
            <div class="side-nav">
                <h4 class="side-nav-title"></h4>
                <ul>
                    <!-- Navigation items will be populated automatically -->
                </ul>
            </div>
        `;
    }

    // Method to refresh the sidebar when content changes
    refresh() {
        this.scanHeaders();
    }

    // Method to set the sidebar title
    setTitle(title) {
        const titleElement = this.querySelector('.side-nav-title');
        if (titleElement) {
            titleElement.textContent = title;
        }
    }
}

// Register the custom element
customElements.define('app-sidebar', Sidebar);

export default Sidebar;
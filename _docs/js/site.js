document.addEventListener('DOMContentLoaded', function() {
    const themeToggle = document.getElementById('theme-toggle');
    const sunIcon = document.getElementById('sun-icon');
    const moonIcon = document.getElementById('moon-icon');
    if (!themeToggle || !sunIcon || !moonIcon) return;

    function setTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        localStorage.setItem('theme', theme);
        sunIcon.style.display = theme === 'light' ? 'block' : 'none';
        moonIcon.style.display = theme === 'light' ? 'none' : 'block';
    }

    themeToggle.addEventListener('click', function() {
        const current = document.documentElement.getAttribute('data-theme') || 'dark';
        setTheme(current === 'dark' ? 'light' : 'dark');
    });

    // Initialize
    const saved = localStorage.getItem('theme') || 'dark';
    setTheme(saved);

    // Set side-nav-title to the first h1's text
    var h1 = document.querySelector('.content-wrapper h1');
    var sideNavTitle = document.querySelector('.side-nav-title');
    if (h1 && sideNavTitle) {
        sideNavTitle.textContent = h1.textContent;
    }
});

// Highlight sidenav link on scroll (shared for all pages)
function setupSideNavHighlight() {
    const navLinks = document.querySelectorAll('.side-nav a');
    if (!navLinks.length) return;
    const sections = Array.from(navLinks).map(link => {
        const id = link.getAttribute('href').replace('#', '');
        return document.getElementById(id);
    });
    function getHeaderOffset() {
        const header = document.querySelector('header');
        return header ? header.offsetHeight : 0;
    }
    function onScroll() {
        const headerOffset = getHeaderOffset();
        let activeIdx = 0;
        const scrollPos = window.scrollY + headerOffset + 1;
        // Highlight the first section if at the very top
        if (window.scrollY === 0) {
            activeIdx = 0;
        } else {
            for (let i = 0; i < sections.length; i++) {
                const section = sections[i];
                const nextSection = sections[i + 1];
                if (section) {
                    const sectionTop = section.offsetTop;
                    const nextSectionTop = nextSection ? nextSection.offsetTop : Infinity;
                    if (scrollPos >= sectionTop && scrollPos < nextSectionTop) {
                        activeIdx = i;
                        break;
                    }
                }
            }
            // Only trigger 'at bottom' logic if truly at the bottom and not at the very top
            const atBottom = Math.abs((window.innerHeight + window.scrollY) - document.body.offsetHeight) < 2;
            if (atBottom && window.scrollY !== 0) {
                activeIdx = sections.length - 1;
            }
        }
        navLinks.forEach((link, i) => {
            if (i === activeIdx) {
                link.classList.add('active');
            } else {
                link.classList.remove('active');
            }
        });
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    onScroll(); // Initial call
}

// Run on DOMContentLoaded
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupSideNavHighlight);
} else {
    setupSideNavHighlight();
}
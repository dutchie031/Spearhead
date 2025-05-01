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
    // Custom scroll on nav click
    navLinks.forEach((link, i) => {
        link.addEventListener('click', function(e) {
            const section = sections[i];
            if (section) {
                e.preventDefault();
                const headerOffset = getHeaderOffset();
                const targetY = window.innerHeight * 0.10;
                const sectionTop = section.getBoundingClientRect().top + window.scrollY;
                const scrollTo = sectionTop - headerOffset - targetY;
                window.scrollTo({ top: scrollTo, behavior: 'smooth' });
            }
        });
    });
    function onScroll() {
        const headerOffset = getHeaderOffset();
        const targetY = window.innerHeight * 0.1; // 30% from the top
        let closestIdx = 0;
        let minDist = Infinity;
        for (let i = 0; i < sections.length; i++) {
            const section = sections[i];
            if (section) {
                const dist = Math.abs(section.getBoundingClientRect().top - headerOffset - targetY);
                if (dist < minDist) {
                    minDist = dist;
                    closestIdx = i;
                }
            }
        }
        navLinks.forEach((link, i) => {
            if (i === closestIdx) {
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
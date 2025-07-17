
class Header extends HTMLElement {

    constructor(){
        super();
    }

    connectedCallback() {
        this.innerHTML = `
            <div class="header-box">
                <a class="logo" href="/index.html">Spearhead</a>
                <span class="subTitle">mission making, made easy</span>
                <div class="header-right">
                    <nav>
                        <a href="/index.html">Home</a>

                        <div class="dropdown">
                            <a href="/pages/tutorials.html">Tutorials</a>
                            <div class="dropdown-content">
                                <a href="/pages/tutorials.html">Quick Starts</a>
                                 <a href="/pages/advanced/CAP.html">Advanced: CAP</a>
                                 <a href="/pages/advanced/missions.html">Advanced: Missions</a>
                            </div>
                        </div>
                        

                        <a href="/pages/persistence.html">Persistence</a>
                        <a href="/pages/reference.html">Reference</a>
                        <a href="/pages/spearheadapi.html">API</a>
                         <a href="/pages/about_us.html">About Us</a>
                    </nav>
                    <button id="theme-toggle" class="theme-toggle" title="Toggle light/dark theme">
                        <svg id="moon-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
                            <path d="M12 11.807A9.002 9.002 0 0 1 10.049 2a9.942 9.942 0 0 0-5.12 2.735c-3.905 3.905-3.905 10.237 0 14.142 3.906 3.906 10.237 3.905 14.143 0a9.946 9.946 0 0 0 2.735-5.119A9.003 9.003 0 0 1 12 11.807z"/>
                        </svg>
                        <svg id="sun-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" style="display: none;">
                            <path d="M6.995 12c0 2.761 2.246 5.007 5.007 5.007s5.007-2.246 5.007-5.007-2.246-5.007-5.007-5.007S6.995 9.239 6.995 12zM12 8.993c1.658 0 3.007 1.349 3.007 3.007S13.658 15.007 12 15.007 8.993 13.658 8.993 12 10.342 8.993 12 8.993zM10.998 19H12.998V22H10.998zM10.998 2H12.998V5H10.998zM1.998 11H4.998V13H1.998zM18.998 11H21.998V13H18.998z"/>
                            <path transform="rotate(-45.017 5.986 18.01)" d="M4.986 17.01H6.986V19.01H4.986z"/>
                            <path transform="rotate(-45.001 18.008 5.99)" d="M17.008 4.99H19.008V6.99H17.008z"/>
                            <path transform="rotate(-134.983 5.988 5.99)" d="M4.988 4.99H6.988V6.99H4.988z"/>
                            <path transform="rotate(134.999 18.008 18.01)" d="M17.008 17.01H19.008V19.01H17.008z"/>
                        </svg>
                    </button>
                </div>
            </div>
        `;
    }


}

customElements.define('app-header', Header);
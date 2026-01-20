class DownloadScript extends HTMLElement {

    constructor(){
        super();
        this.cacheKey = 'spearhead-latest-release';
        this.cacheExpiryMinutes = 15;
    }

    getCachedData() {
        const cached = localStorage.getItem(this.cacheKey);
        if (!cached) return null;
        
        const { data, timestamp } = JSON.parse(cached);
        const now = Date.now();
        const expiry = this.cacheExpiryMinutes * 60 * 1000; // 15 minutes in ms
        
        if (now - timestamp > expiry) {
            localStorage.removeItem(this.cacheKey);
            return null;
        }
        
        return data;
    }

    setCachedData(data) {
        const cacheItem = {
            data: data,
            timestamp: Date.now()
        };
        localStorage.setItem(this.cacheKey, JSON.stringify(cacheItem));
    }

    async fetchLatestRelease() {
        // Check cache first
        const cachedData = this.getCachedData();
        if (cachedData) {
            return cachedData;
        }

        try {
            const response = await fetch('https://api.github.com/repos/dutchie031/Spearhead/releases/latest');
            const data = await response.json();
            
            // Cache the data
            this.setCachedData(data);
            return data;
        } catch (error) {
            console.error('Error fetching latest release:', error);
            return null;
        }
    }

    async fetchReleaseAssets(url){
        try {
            const response = await fetch(url);
            const data = await response.json();
            return data;
        } catch (error) {
            console.error('Error fetching release assets:', error);
            return null;
        }
    }
    
    async connectedCallback() {

        var version = "?";
        var timestamp = "?";
        var size = "?";
        var href = "https://github.com/dutchie031/Spearhead/releases"

        const latestRelease =  await this.fetchLatestRelease();
        if (latestRelease) {
            version = latestRelease.tag_name;
            timestamp = new Date(latestRelease.published_at).toLocaleDateString('en-CA');

            const assets = await this.fetchReleaseAssets(latestRelease.assets_url);
            if (assets && assets.length > 0) {
                const spearheadAsset = assets.find(asset => asset.name.includes('spearhead'));
                if (spearheadAsset) {
                    size = (spearheadAsset.size / 1024).toFixed(2) + 'kb';
                    href = spearheadAsset.browser_download_url;
                }
            }
        }

        this.innerHTML = /*html*/`
            <div class="latest-version-download-box">
                <style>
                    .latest-version-download-box {
                        display: flex;
                    }

                    .latest-version-download-content {
                        border: 1px solid #ccc;
                        border-radius: 8px;
                        padding: 0px 16px;
                    }

                    .version-text {
                        font-weight: bold;
                        color: #f5efefff
                    }
                </style>
                <div class="latest-version-download-content">
                    <p>
                        <span class="version-text">${version}</span> (${timestamp}) <br>
                        <a style="text-decoration: underline;" target="_blank" href="${href}">Download</a> (${size}) <br>
                        <a style="text-decoration: underline;" target="_blank" href="https://github.com/dutchie031/Spearhead/releases">See All Versions here</a>
                    </p>
                </div>

                
            </div>
        `;
    }

}

customElements.define('download-spearhead', DownloadScript);
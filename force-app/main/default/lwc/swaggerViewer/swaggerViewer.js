import { LightningElement } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import SWAGGER_UI from '@salesforce/resourceUrl/swaggerui';
import OPENAPI_SPEC from '@salesforce/resourceUrl/OPENAPI_SPEC';

export default class SwaggerViewer extends LightningElement {
    swaggerInitialized = false;

    renderedCallback() {
        if (this.swaggerInitialized) {
            return;
        }
        this.swaggerInitialized = true;

        console.log('Starting Swagger UI initialization...');
        
        // Step 1: Load the OpenAPI spec
        fetch(OPENAPI_SPEC)
            .then(response => {
                console.log('OpenAPI spec fetch response:', response.status);
                return response.json();
            })
            .then(spec => {
                console.log('OpenAPI spec loaded successfully');
                // Step 2: Load Swagger UI CSS
                return loadStyle(this, SWAGGER_UI + '/swagger-ui.css')
                    .then(() => {
                        console.log('Swagger UI CSS loaded successfully');
                        // Step 3: Load Swagger UI JS
                        return loadScript(this, SWAGGER_UI + '/swagger-ui-bundle.js')
                            .then(() => {
                                console.log('Swagger UI Bundle loaded successfully');
                                return loadScript(this, SWAGGER_UI + '/swagger-ui-standalone-preset.js');
                            });
                    })
                    .then(() => {
                        console.log('Swagger UI Standalone Preset loaded successfully');
                        return spec;
                    });
            })
            .then(spec => {
                console.log('Initializing Swagger UI with spec');
                const container = this.template.querySelector('.swagger-container');
                console.log('Container found:', container ? 'yes' : 'no');
                
                if (!container) {
                    throw new Error('Swagger container element not found');
                }

                try {
                    // Create a new div for React to render into
                    const reactRoot = document.createElement('div');
                    reactRoot.id = 'swagger-ui-root';
                    container.appendChild(reactRoot);

                    // Determine the correct redirect URL based on context
                    const isLightning = window.location.hostname.includes('lightning.force.com');
                    const isSite = window.location.hostname.includes('my.site.com');
                    
                    let oauth2RedirectUrl;
                    if (isLightning) {
                        oauth2RedirectUrl = `${window.location.origin}/lightning/n/SwaggerUI`;
                    } else if (isSite) {
                        oauth2RedirectUrl = `${window.location.origin}/api/docs`;
                    } else {
                        oauth2RedirectUrl = `${window.location.origin}/api/oauth2-redirect.html`;
                    }
                    
                    console.log('OAuth2 Redirect URL:', oauth2RedirectUrl);

                    // Initialize Swagger UI
                    window.SwaggerUIBundle({
                        spec: spec,
                        dom_id: '#swagger-ui-root',
                        deepLinking: true,
                        presets: [
                            window.SwaggerUIBundle.presets.apis,
                            window.SwaggerUIStandalonePreset
                        ],
                        plugins: [
                            window.SwaggerUIBundle.plugins.DownloadUrl
                        ],
                        layout: "StandaloneLayout",
                        oauth2RedirectUrl: oauth2RedirectUrl,
                        onComplete: () => {
                            console.log('Swagger UI initialization complete');
                            // Add OAuth configuration
                            window.ui.initOAuth({
                                scopes: 'offline_access refresh_token api',
                                usePkceWithAuthorizationCodeGrant: true,
                                redirectUrl: oauth2RedirectUrl
                            });
                        }
                    });
                    console.log('Swagger UI initialized successfully');
                } catch (error) {
                    console.error('Error during Swagger UI initialization:', error.message);
                    throw error;
                }
            })
            .catch(error => {
                console.error('Error in Swagger UI initialization:', error.message || 'Unknown error');
                if (error.stack) {
                    console.error('Stack trace:', error.stack);
                }
            });
    }
}
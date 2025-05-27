import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import OPENAPI_SPEC from '@salesforce/resourceUrl/OPENAPI_SPEC';

export default class SwaggerJsonViewer extends LightningElement {
    openApiSpec = null;
    error = null;
    initialized = false;

    renderedCallback() {
        if (this.initialized) {
            return;
        }
        this.initialized = true;
        this.loadOpenApiSpec();
    }

    async loadOpenApiSpec() {
        try {
            const response = await fetch(OPENAPI_SPEC);
            this.openApiSpec = await response.json();
        } catch (error) {
            this.error = error.message;
            console.error('Error loading OpenAPI spec:', error);
        }
    }

    get openApiSpecString() {
        return this.openApiSpec ? JSON.stringify(this.openApiSpec, null, 2) : '';
    }

    handleCopy() {
        if (!this.openApiSpec) return;
        
        navigator.clipboard.writeText(this.openApiSpecString)
            .then(() => {
                this.showToast('Success', 'JSON copied to clipboard', 'success');
            })
            .catch(error => {
                console.error('Error copying to clipboard:', error);
                this.showToast('Error', 'Failed to copy to clipboard', 'error');
            });
    }

    handleDownload() {
        if (!this.openApiSpec) return;

        const blob = new Blob([this.openApiSpecString], { type: 'application/json' });
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'openapi-spec.json';
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
} 
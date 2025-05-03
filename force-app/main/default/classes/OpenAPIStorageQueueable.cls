/**
 * Queueable class for storing OpenAPI specifications as a Static Resource
 * Handles the HTTP callout outside of batch context to avoid mixed DML errors
 */
public class OpenAPIStorageQueueable implements Queueable, Database.AllowsCallouts {
    
    private Map<String, Object> spec;
    private String resourceName;
    
    /**
     * Constructor
     * @param spec The OpenAPI specification to store
     * @param resourceName The name of the Static Resource
     */
    public OpenAPIStorageQueueable(Map<String, Object> spec, String resourceName) {
        this.spec = spec;
        this.resourceName = resourceName;
    }
    
    /**
     * Execute method for the queueable
     */
    public void execute(QueueableContext context) {
        try {
            storeAsStaticResource(spec, resourceName);
            System.debug('Successfully stored OpenAPI spec as Static Resource: ' + resourceName);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error storing OpenAPI spec: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getStackTraceString());
        }
    }
    
    /**
     * Stores the OpenAPI specification as a Static Resource
     * @param spec The OpenAPI specification to store
     * @param resourceName The name of the Static Resource
     */
    private void storeAsStaticResource(Map<String, Object> spec, String resourceName) {
        // Convert spec to JSON string with some optimizations for large specs
        String jsonSpec = JSON.serialize(spec); // Using serialize instead of serializePretty for large specs
        
        // First try to get the existing Static Resource
        HttpRequest getReq = new HttpRequest();
        getReq.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/query?q=SELECT+Id+FROM+StaticResource+WHERE+Name=\'' + resourceName + '\'');
        getReq.setMethod('GET');
        getReq.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        
        Http http = new Http();
        HttpResponse getRes = http.send(getReq);
        
        String resourceId = null;
        if (getRes.getStatusCode() == 200) {
            Map<String, Object> queryResult = (Map<String, Object>)JSON.deserializeUntyped(getRes.getBody());
            List<Object> records = (List<Object>)queryResult.get('records');
            if (!records.isEmpty()) {
                Map<String, Object> record = (Map<String, Object>)records[0];
                resourceId = (String)record.get('Id');
            }
        }
        
        // Create or update the Static Resource
        HttpRequest req = new HttpRequest();
        if (resourceId != null) {
            // Update existing resource
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/StaticResource/' + resourceId);
            req.setMethod('PATCH');
        } else {
            // Create new resource
            req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/sobjects/StaticResource');
            req.setMethod('POST');
        }
        
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        
        // Check if the spec might be too large for a single Static Resource (5MB limit)
        Blob jsonBlob = Blob.valueOf(jsonSpec);
        if (jsonBlob.size() > 4.5 * 1024 * 1024) { // 4.5MB warning threshold
            System.debug(LoggingLevel.WARN, 'WARNING: OpenAPI specification is approaching the 5MB Static Resource limit: ' + 
                         (jsonBlob.size() / (1024.0 * 1024.0)).setScale(2) + 'MB');
        }
        
        // Create the Static Resource body with correct field names
        Map<String, Object> body = new Map<String, Object>{
            'Name' => resourceName,
            'ContentType' => 'application/json',
            'CacheControl' => 'Public',
            'Body' => EncodingUtil.base64Encode(jsonBlob)
        };
        
        req.setBody(JSON.serialize(body));
        
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() != 201 && res.getStatusCode() != 204) {
            throw new OpenAPIParser.OpenAPIParserException('Failed to ' + (resourceId != null ? 'update' : 'create') + 
                                                         ' Static Resource: ' + res.getBody());
        }
    }
} 
public class MetadataService {
    public class SessionHeader_element {
        public String sessionId;
        private String[] sessionId_type_info = new String[]{'sessionId','http://soap.sforce.com/2006/04/metadata',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'http://soap.sforce.com/2006/04/metadata','true','false'};
        private String[] field_order_type_info = new String[]{'sessionId'};
    }
    
    public class StaticResource {
        public String fullName;
        public String contentType;
        public String cacheControl;
        public String content;
        private String[] fullName_type_info = new String[]{'fullName','http://soap.sforce.com/2006/04/metadata',null,'0','1','false'};
        private String[] contentType_type_info = new String[]{'contentType','http://soap.sforce.com/2006/04/metadata',null,'1','1','false'};
        private String[] cacheControl_type_info = new String[]{'cacheControl','http://soap.sforce.com/2006/04/metadata',null,'1','1','false'};
        private String[] content_type_info = new String[]{'content','http://soap.sforce.com/2006/04/metadata',null,'1','1','false'};
        private String[] apex_schema_type_info = new String[]{'http://soap.sforce.com/2006/04/metadata','true','false'};
        private String[] field_order_type_info = new String[]{'fullName','contentType','cacheControl','content'};
    }
    
    public class AsyncResult {
        public Boolean done;
        public String id;
        public String message;
        public String state;
        public String statusCode;
        private String[] done_type_info = new String[]{'done','http://soap.sforce.com/2006/04/metadata',null,'1','1','false'};
        private String[] id_type_info = new String[]{'id','http://soap.sforce.com/2006/04/metadata',null,'1','1','false'};
        private String[] message_type_info = new String[]{'message','http://soap.sforce.com/2006/04/metadata',null,'0','1','false'};
        private String[] state_type_info = new String[]{'state','http://soap.sforce.com/2006/04/metadata',null,'1','1','false'};
        private String[] statusCode_type_info = new String[]{'statusCode','http://soap.sforce.com/2006/04/metadata',null,'0','1','false'};
        private String[] apex_schema_type_info = new String[]{'http://soap.sforce.com/2006/04/metadata','true','false'};
        private String[] field_order_type_info = new String[]{'done','id','message','state','statusCode'};
    }
    
    public class MetadataPort {
        public String endpoint_x = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/62.0';
        public Map<String,String> inputHttpHeaders_x;
        public Map<String,String> outputHttpHeaders_x;
        public String clientCertName_x;
        public String clientCert_x;
        public String clientCertPasswd_x;
        public Integer timeout_x;
        public SessionHeader_element SessionHeader;
        private String SessionHeader_hns = 'SessionHeader=http://soap.sforce.com/2006/04/metadata';
        private String[] ns_map_type_info = new String[]{'http://soap.sforce.com/2006/04/metadata','MetadataService'};
        
        public AsyncResult[] create(Metadata[] metadata) {
            MetadataService.create_element request_x = new MetadataService.create_element();
            request_x.metadata = metadata;
            MetadataService.createResponse_element response_x;
            Map<String, MetadataService.createResponse_element> response_map_x = new Map<String, MetadataService.createResponse_element>();
            response_map_x.put('response_x', response_x);
            WebServiceCallout.invoke(
                this,
                request_x,
                response_map_x,
                new String[]{endpoint_x,
                '',
                'http://soap.sforce.com/2006/04/metadata',
                'create',
                'http://soap.sforce.com/2006/04/metadata',
                'createResponse',
                'MetadataService.createResponse_element'}
            );
            response_x = response_map_x.get('response_x');
            return response_x.result;
        }
    }
    
    public class create_element {
        public Metadata[] metadata;
        private String[] metadata_type_info = new String[]{'metadata','http://soap.sforce.com/2006/04/metadata',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'http://soap.sforce.com/2006/04/metadata','true','false'};
        private String[] field_order_type_info = new String[]{'metadata'};
    }
    
    public class createResponse_element {
        public AsyncResult[] result;
        private String[] result_type_info = new String[]{'result','http://soap.sforce.com/2006/04/metadata',null,'0','-1','false'};
        private String[] apex_schema_type_info = new String[]{'http://soap.sforce.com/2006/04/metadata','true','false'};
        private String[] field_order_type_info = new String[]{'result'};
    }
} 
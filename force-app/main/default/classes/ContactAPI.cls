/**
 * @openapi
 * @title Contact API
 * @description REST API for managing Contact records
 * @version 1.0.0
 */
@RestResource(urlMapping='/api/v1/contacts/*')
global with sharing class ContactAPI {

    /**
     * @openapi
     * @operation getContact
     * @summary Get Contact Details
     * @description Retrieves contact information by ID
     * @param id path string required Contact ID
     * @response 200 Contact Success
     * @response 404 Error Contact not found
     */
    @HttpGet
    global static Contact getContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        try {
            Contact contact = [SELECT Id, FirstName, LastName, Email, Phone, AccountId FROM Contact WHERE Id = :contactId];
            return contact;
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            return null;
        }
    }

    /**
     * @openapi
     * @operation createContact
     * @summary Create New Contact
     * @description Creates a new contact record
     * @response 201 Contact Contact created
     * @response 400 Error Invalid input
     */
    @HttpPost
    global static Contact createContact() {
        RestRequest req = RestContext.request;
        Contact contact = (Contact)JSON.deserialize(req.requestBody.toString(), Contact.class);
        
        try {
            insert contact;
            RestContext.response.statusCode = 201;
            return contact;
        } catch (DmlException e) {
            RestContext.response.statusCode = 400;
            return null;
        }
    }

    /**
     * @openapi
     * @operation updateContact
     * @summary Update Contact
     * @description Updates an existing contact record
     * @param id path string required Contact ID
     * @response 200 Contact Contact updated
     * @response 404 Error Contact not found
     */
    @HttpPut
    global static Contact updateContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        Contact contact = (Contact)JSON.deserialize(req.requestBody.toString(), Contact.class);
        contact.Id = contactId;
        
        try {
            update contact;
            return contact;
        } catch (DmlException e) {
            RestContext.response.statusCode = 404;
            return null;
        }
    }

    /**
     * @openapi
     * @operation deleteContact
     * @summary Delete Contact
     * @description Deletes a contact record
     * @param id path string required Contact ID
     * @response 204 content
     * @response 404 Error Contact not found
     */
    @HttpDelete
    global static void deleteContact() {
        RestRequest req = RestContext.request;
        String contactId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        try {
            Contact contact = [SELECT Id FROM Contact WHERE Id = :contactId];
            delete contact;
            RestContext.response.statusCode = 204;
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
        }
    }
} 
/**
 * @openapi
 * @title Account API
 * @description REST API for managing Account records
 * @version 1.0.0
 */
@RestResource(urlMapping='/api/v1/accounts/*')
global with sharing class AccountAPI {
    
    /**
     * @openapi
     * @operation getAccount
     * @summary Get Account Details
     * @description Retrieves account information by ID
     * @param id path string required Account ID
     * @response 200 {object} Account Success
     * @response 404 {object} Error Account not found
     */
    @HttpGet
    global static Account getAccount() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        try {
            Account acc = [SELECT Id, Name, Industry, Type, BillingAddress 
                          FROM Account 
                          WHERE Id = :accountId 
                          WITH SECURITY_ENFORCED];
            return acc;
        } catch (QueryException e) {
            RestContext.response.statusCode = 404;
            return null;
        }
    }
    
    /**
     * @openapi
     * @operation createAccount
     * @summary Create New Account
     * @description Creates a new account record
     * @body {object} Account Account details
     * @response 201 {object} Account Account created
     * @response 400 {object} Error Invalid input
     */
    @HttpPost
    global static Account createAccount() {
        RestRequest req = RestContext.request;
        Account newAccount = (Account)JSON.deserialize(req.requestBody.toString(), Account.class);
        
        try {
            insert newAccount;
            RestContext.response.statusCode = 201;
            return newAccount;
        } catch (DmlException e) {
            RestContext.response.statusCode = 400;
            return null;
        }
    }
    
    /**
     * @openapi
     * @operation updateAccount
     * @summary Update Account
     * @description Updates an existing account record
     * @param id path string required Account ID
     * @body {object} Account Updated account details
     * @response 200 {object} Account Account updated
     * @response 404 {object} Error Account not found
     */
    @HttpPut
    global static Account updateAccount() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        Account updatedAccount = (Account)JSON.deserialize(req.requestBody.toString(), Account.class);
        updatedAccount.Id = accountId;
        
        try {
            update updatedAccount;
            return updatedAccount;
        } catch (DmlException e) {
            RestContext.response.statusCode = 404;
            return null;
        }
    }
    
    /**
     * @openapi
     * @operation deleteAccount
     * @summary Delete Account
     * @description Deletes an account record
     * @param id path string required Account ID
     * @response 204 No content
     * @response 404 {object} Error Account not found
     */
    @HttpDelete
    global static void deleteAccount() {
        RestRequest req = RestContext.request;
        String accountId = req.requestURI.substring(req.requestURI.lastIndexOf('/') + 1);
        
        try {
            Account acc = [SELECT Id FROM Account WHERE Id = :accountId WITH SECURITY_ENFORCED];
            delete acc;
            RestContext.response.statusCode = 204;
        } catch (Exception e) {
            RestContext.response.statusCode = 404;
        }
    }
} 
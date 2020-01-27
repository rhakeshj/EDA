/*
    Copyright (c) 2020, Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2020
* @group Course Enrollments
* @group-content ../../ApexDocContent/CourseEnrollments.htm
* @description This is a batch class that backfills existing Student Course Connection with missing Affiliation.
*/
public class CCON_AffiliationBackfill_BATCH implements Database.Batchable<SObject>{
    //Test test
    public Database.Querylocator start(Database.BatchableContext bc) {
        Id studentCCRecordTypeId = UTIL_CustomSettingsFacade.getSettings().Student_RecType__c;
        String query = 'SELECT Id, Program_Enrollment__c, Affiliation__c ' +
                        'FROM Course_Enrollment__c ' +
            			'WHERE Affiliation__c = NULL AND Program_Enrollment__c != NULL AND RecordTypeId = :studentCCRecordTypeId';

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<Course_Enrollment__c> returnCourseEnrollments){
        List<Id> pEnrollmentID = new List<Id>();
        List<Course_Enrollment__c> courseEnrollmentsToUpdate = new List<Course_Enrollment__c>();

        if (returnCourseEnrollments.size () > 0) {

            for (Integer i = 0; i < returnCourseEnrollments.size(); i++) {
                Course_Enrollment__c enroll = returnCourseEnrollments[i];
                if (enroll.Program_Enrollment__c != NULL) {
                    pEnrollmentID.add(enroll.Program_Enrollment__c);
                }
            }

            if (pEnrollmentID.size () > 0) {
                List<Program_Enrollment__c> queryPE = [SELECT Id, Affiliation__c, Account__c
                                                  FROM Program_Enrollment__c
                                                  WHERE Id = :pEnrollmentID];
                Map<Id, Program_Enrollment__c> pEnrollmentsMap = new Map<Id, Program_Enrollment__c>(queryPE);

                for (Course_Enrollment__c courseEnroll : returnCourseEnrollments) {
                    courseEnroll.Affiliation__c = pEnrollmentsMap.get(courseEnroll.Program_Enrollment__c).Affiliation__c;
                    courseEnroll.Account__c = pEnrollmentsMap.get(courseEnroll.Program_Enrollment__c).Account__c;
                    courseEnrollmentsToUpdate.add(courseEnroll);
                }

            }
        }

        if (courseEnrollmentsToUpdate.size() > 0) {
            update courseEnrollmentsToUpdate;
        }
    }

    public void finish(Database.BatchableContext bc) {
   	    AsyncApexJob a = [SELECT Id, Status, JobType, NumberOfErrors,
                          JobItemsProcessed, TotalJobItems, CompletedDate,
                          ExtendedStatus, CreatedById, CreatedBy.Email
        				  FROM AsyncApexJob
                          WHERE Id =:bc.getJobId()];

       	Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String> {a.CreatedBy.Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Backfill of Affiliation on Student Course Connection Status : ' + a.Status);
            mail.setPlainTextBody('The batch Apex job processed ' + a.TotalJobItems +
           ' batches with '+ a.NumberOfErrors + ' failures.');
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}
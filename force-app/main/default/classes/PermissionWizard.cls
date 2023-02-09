public with sharing class PermissionWizard {
    
    @AuraEnabled
    public static void updateFieldPermissions(String objectApiName, String fieldsDataString){
        List<FieldPermissions> fps = new List<FieldPermissions>();
        List<FieldPermissions> fpsToDelete = new List<FieldPermissions>();

        List<FieldData> fieldsData = (List<FieldData>)JSON.deserialize(fieldsDataString, List<FieldData>.class);

        for(FieldData fd : fieldsData){
            for(FieldPermission fp : fd.permissions){
                if(fp.changed){
                    FieldPermissions fpRecord = new FieldPermissions(
                        Field = objectApiName + '.' + fd.fieldName,
                        ParentId = fp.permissionId, 
                        SObjectType = objectApiName,
                        PermissionsRead = fp.read,
                        PermissionsEdit = fp.write
                    );

                    if(fp.Id != null){
                        fpRecord.Id = fp.Id;
                    }

                    if(fpRecord.Id != null && !fpRecord.PermissionsRead && !fpRecord.PermissionsEdit){
                        fpsToDelete.add(fpRecord);
                    }else{
                        fps.add(fpRecord);
                    }
                }
            }
        }
        if(fps.size() > 0){
            upsert fps;
        }
        if(fpsToDelete.size() > 0){
            delete fpsToDelete;
        }
    }
   

    @AuraEnabled
    public static List<FieldData> getFieldPermissions(String objectApiName, List<String> permissionSets){
        Map<String, Map<String, FieldPermission>> mapPermByField = new Map<String, Map<String, FieldPermission>>();

        List<Map<String, String>> fields = new List<Map<String, String>>();

        SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
        Map<String,Schema.SObjectField> mapFields = objectType.getDescribe().fields.getMap();
        List<String> fieldKeys = new List<String>(mapFields.keySet());
        fieldKeys.sort();

        Map<Id, PermissionSet> mapPermissionSets = new Map<Id, PermissionSet>([SELECT Id, Label, Name FROM PermissionSet WHERE Name IN :permissionSets]);
        Map<String, Id> psetIdByName = new Map<String, Id>();

        for(PermissionSet ps : mapPermissionSets.values()){
            psetIdByName.put(ps.Name, ps.Id);
        }


        for(String fieldname : fieldKeys){
            Schema.DescribeFieldResult fieldDescription =  mapFields.get(fieldname).getDescribe();
            Map<String, String> fieldInfo = new Map<String, String>();
            // fieldInfo.put('apiName', fieldDescription.getName());
            // fieldInfo.put('label', fieldDescription.getLabel());
            // fields.add(fieldInfo);
            String fieldApiName = fieldDescription.getName();

            if(!mapPermByField.containsKey(fieldApiName)){
                mapPermByField.put(fieldApiName, new Map<String, FieldPermission>());
            }

            for(String permissionSet : permissionSets){
                if(!mapPermByField.get(fieldApiName).containsKey(permissionSet)){
                    Id relatedPsetId = psetIdByName.get(permissionSet);

                    FieldPermission fp = new FieldPermission();
                    fp.read = false;
                    fp.write = false;
                    fp.permissionId = relatedPsetId;
                    fp.disableread = false;
                    fp.disablewrite = false;

                    // For required fields
                    if(!fieldDescription.isPermissionable()){
                        fp.read = true;
                        fp.write = true;
                        fp.disableread = true;
                        fp.disablewrite = true;
                    }

                    // For formula fields
                    if(fieldDescription.isCalculated()){
                        fp.disablewrite = true;
                    }

                    mapPermByField.get(fieldApiName).put(permissionSet, fp);
                }
            }
        }

        for(FieldPermissions fp : [SELECT Id, Field, ParentId, PermissionsEdit, PermissionsRead FROM FieldPermissions WHERE SobjectType = :objectApiName AND ParentId IN :mapPermissionSets.keySet()]){
            PermissionSet relatedPset = mapPermissionSets.get(fp.ParentId);
            String fieldName = fp.Field.remove(objectApiName + '.');

            mapPermByField.get(fieldName).get(relatedPset.Name).read = fp.PermissionsRead;
            mapPermByField.get(fieldName).get(relatedPset.Name).write = fp.PermissionsEdit;
            mapPermByField.get(fieldName).get(relatedPset.Name).Id = fp.Id;
            mapPermByField.get(fieldName).get(relatedPset.Name).permissionId = relatedPset.Id;
        }

        // Convert to List
        List<FieldData> fieldData = new List<FieldData>();
        for(String fieldName : mapPermByField.keySet()){
            FieldData fd = new FieldData();
            fd.fieldName = fieldName;

            List<FieldPermission> perms = new List<FieldPermission>();

            for(String permissionName : mapPermByField.get(fieldName).keySet()){
                FieldPermission fpm = new FieldPermission();
                fpm.permission = permissionName;
                fpm.Id = mapPermByField.get(fieldName).get(permissionName).Id;
                fpm.permissionId = mapPermByField.get(fieldName).get(permissionName).permissionId;
                fpm.read = mapPermByField.get(fieldName).get(permissionName).read;
                fpm.write = mapPermByField.get(fieldName).get(permissionName).write;
                fpm.disableread = mapPermByField.get(fieldName).get(permissionName).disableread;
                fpm.disablewrite = mapPermByField.get(fieldName).get(permissionName).disablewrite;
                fpm.readkey = fpm.permission + fieldName + 'read';
                fpm.writekey = fpm.permission + fieldName + 'write';
                fpm.changed = false;

                perms.add(fpm);
            }

            fd.permissions = perms;
            fieldData.add(fd);
        }

        return fieldData;
    }

    public class FieldData{

        @AuraEnabled
        public String fieldName;
        @AuraEnabled
        public List<FieldPermission> permissions;
    }

    public class FieldPermission{
        @AuraEnabled
        public String permission;
        @AuraEnabled
        public String permissionId;
        @AuraEnabled
        public Boolean read;
        @AuraEnabled
        public Boolean disableread;
        @AuraEnabled
        public Boolean write;
        @AuraEnabled
        public Boolean disablewrite;
        @AuraEnabled
        public Boolean changed;
        @AuraEnabled
        public String Id;
        @AuraEnabled
        public String readKey;
        @AuraEnabled
        public String writeKey;
    }
}
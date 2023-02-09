import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getFieldPermissions from '@salesforce/apex/PermissionWizard.getFieldPermissions';
import updateFieldPermissions from '@salesforce/apex/PermissionWizard.updateFieldPermissions';

const initColumns = [
    { label: 'Field', key: 'fieldApiName', colspan: '', class: 'field' }
];
const initSubColumns = [
    { label: 'API Name', key: 'fieldApiName', class: 'subHeader', checkbox: false}
];

export default class PermissionWizard extends LightningElement {
    objectApiName ='Ticket__c';
    permissionSets='BRD_Admin;BRD_User';
    loading=false;
    executed=false;
    disableUpdate;
    section;
    updateGlobalCheckbox=false;
    columns = [];
    subColumns = [];
    @track fieldsData = [];

    connectedCallback(){
        this.disableUpdate = true;
    }


    fieldPermissions(){
        this.section = 'fieldPermissions';
        this.disableUpdate = true;
        this.loading = true;
        this.executed = false;
        this.columns = [...initColumns];
        this.subColumns = [...initSubColumns];

        let psetCpt = 0;
        for(let permissionSet of this.permissionSets.split(';')){
            this.columns.push({
                label: permissionSet,
                value: permissionSet,
                class: psetCpt % 2 ? 'permission-set-1' : 'permission-set-2',
                colspan: 2
            });

            this.subColumns.push({
                key: permissionSet + 'read',
                permissionSet: permissionSet,
                class: 'subHeader subHeaderCheck',
                checkbox: true,
                value: 'read',
                label: 'Read'
            });
            this.subColumns.push({
                key: permissionSet + 'write',
                permissionSet: permissionSet,
                class: 'subHeader subHeaderCheck',
                checkbox: true,
                value: 'write',
                label: 'Edit'
            });

            psetCpt++;
        }

        getFieldPermissions({ objectApiName: this.objectApiName, permissionSets: this.permissionSets.split(';') })
        .then(data => {
            this.fieldsData = [...data].map(field => {
                let permCpt = 0;
                for(let permission of field.permissions){
                    permission.class = permCpt % 2 ? 'permission' : 'permission permission-altered';
                    permCpt++;
                }

                return field;
            });
            console.log(JSON.stringify(this.fieldsData));

            this.loading = false;
            this.executed = true;
        })
        .catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error while retrieving permissions',
                    message: error.message,
                    variant: 'error'
                })
            );
            this.loading = false;
        });

        // getFields({ objectApiName: this.objectApiName }).then(data => {
        //     // console.log(JSON.stringify(data));

        //     this.fieldsData = [...data].map(field => {
        //         let fieldData = {
        //             fieldApiName: field.apiName
        //         };
                

        //     });

        // });
    }

    handleObjectChange(event) { this.objectApiName = event.detail.value; }
    handlePermissionSetsChange(event) { this.permissionSets = event.detail.value; }

    handleCheckbox(event){
        if(!this.updateGlobalCheckbox){
            let fieldName = event.currentTarget.dataset.field;
            let permissionSet = event.currentTarget.dataset.permission;
            let action = event.currentTarget.dataset.action;
            let checked = event.target.checked;
            console.log(permissionSet);
            console.log(action);
            console.log(checked);
            console.log(fieldName);

            for(let fieldData of this.fieldsData){
                if(fieldData.fieldName == fieldName){
                    for(let permission of fieldData.permissions){
                        if(permission.permission == permissionSet){
                            permission[action] = checked;
                            permission.changed = true;
                            permission.class = 'permission changed';
                            this.disableUpdate = false;
                            console.log(JSON.stringify(permission));
                        }
                    }
                }
            }
        }
    }

    handleGlobalCheckbox(event){
        let permissionSet = event.currentTarget.dataset.permission;
        let action = event.currentTarget.dataset.action;
        let checked = event.target.checked;
        this.updateGlobalCheckbox = true;

        for(let fieldData of this.fieldsData){
            for(let permission of fieldData.permissions){
                let disableAction = 'disable' + action;
                if(permission.permission == permissionSet && !permission.required && !permission[disableAction]){
                    permission[action] = checked;
                    // if(action == 'write' && checked){
                    //     permission.read = checked;
                    // }
                    permission.changed = true;
                    permission.class = 'permission changed';
                    this.disableUpdate = false;
                }
            }
        }
        this.updateGlobalCheckbox = false;
    }

    handleUpdate(){
        // console.log(JSON.stringify(this.fieldsData));
        this.disableUpdate = true;
        this.loading = true;
        // TODO: Filter changed rows on Front side to avoid sending too much data to backend for nothing
        updateFieldPermissions( { objectApiName: this.objectApiName, fieldsDataString: JSON.stringify(this.fieldsData) })
        .then(data => {
            const evt = new ShowToastEvent({
                title: "Permissions updated",
                message: '',
                variant: "success"
            });
            this.dispatchEvent(evt);
            this.loading = false;
        })
        .catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error while updating permissions',
                    message: error.message,
                    variant: 'error'
                })
            );
            console.log(error);
            this.loading = false;
            this.disableUpdate = false;
        });;
    }
}
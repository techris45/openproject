import { TestBed } from '@angular/core/testing';
import { DynamicFormService } from "core-app/modules/common/dynamic-forms/services/dynamic-form/dynamic-form.service";
import { HttpClientTestingModule, HttpTestingController } from "@angular/common/http/testing";
import { HttpClient } from "@angular/common/http";
import { IOPDynamicForm, IOPForm } from "core-app/modules/common/dynamic-forms/typings";
import { DynamicFieldsService } from "core-app/modules/common/dynamic-forms/services/dynamic-fields/dynamic-fields.service";
import { FormGroup } from "@angular/forms";
import { of } from "rxjs";

xdescribe('DynamicFormService', () => {
  let httpClient: HttpClient;
  let httpTestingController: HttpTestingController;
  let service:DynamicFormService;
  const testFormUrl = 'http://op.com/form';
  const formSchema:IOPForm = {
    "_type": "Form",
    "_embedded": {
      "payload": {
        "name": "Project 1",
        "_links": {
          "parent": {
            "href": "/api/v3/projects/26",
            "title": "Parent project"
          }
        }
      },
      "schema": {
        "_type": "Schema",
        "_dependencies": [],
        "name": {
          "type": "String",
          "name": "Name",
          "required": true,
          "hasDefault": false,
          "writable": true,
          "minLength": 1,
          "maxLength": 255,
          "options": {}
        },
        "parent": {
          "type": "Project",
          "name": "Subproject of",
          "required": false,
          "hasDefault": false,
          "writable": true,
          "_links": {
            "allowedValues": {
              "href": "/api/v3/projects/available_parent_projects?of=25"
            }
          }
        },
        "_links": {}
      },
      "validationErrors": {}
    },
    "_links": {
      "self": {
        "href": "/api/v3/projects/25/form",
        "method": "post"
      },
      "validate": {
        "href": "/api/v3/projects/25/form",
        "method": "post"
      },
      "commit": {
        "href": "/api/v3/projects/25",
        "method": "patch"
      }
    }
  };
  const dynamicFormConfig:IOPDynamicForm = {
    "fields": [
      {
        "type": "textInput",
        "className": "op-form--field inline-edit--field",
        "key": "name",
        "templateOptions": {
          "required": true,
          "label": "Name",
          "type": "text"
        }
      },
      {
        "type": "selectInput",
        "className": "op-form--field inline-edit--field Subproject of",
        "expressionProperties": {},
        "key": "_links.parent",
        "templateOptions": {
          "required": false,
          "label": "Subproject of",
          "type": "number",
          "locale": "en",
          "bindLabel": "title",
          "searchable": false,
          "virtualScroll": true,
          "typeahead": false,
          "clearOnBackspace": false,
          "clearSearchOnAdd": false,
          "hideSelected": false,
          "text": {
            "add_new_action": "Create"
          },
          "options": of([]),
        }
      }
    ],
    "model": {
      "name": "Project 1",
      "_links": {
        "parent": {
          "href": "/api/v3/projects/26",
          "title": "Parent project",
          "name": "Parent project"
        }
      }
    },
    "form": new FormGroup({}),
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [
        HttpClientTestingModule,
      ],
      providers: [
        DynamicFormService,
        DynamicFieldsService,
      ]
    });
    httpClient = TestBed.inject(HttpClient);
    httpTestingController = TestBed.inject(HttpTestingController);
    service = TestBed.inject(DynamicFormService);
  });

  it('should be created', () => {
    expect(service).toBeTruthy();
  });

  it('should return the dynamic form config from the backend response', () => {
    service
      .getForm$(testFormUrl)
      .subscribe(dynamicFormConfigResponse => {
        expect(dynamicFormConfigResponse.fields.length).toEqual(dynamicFormConfig.fields.length, 'should return one dynamic field per schema field');
        expect(
          dynamicFormConfigResponse.fields.every((field, index) => field.type === dynamicFormConfig.fields[index].type)
        )
        .toBe(true, 'should return the dynamic fields in the schema order');
        expect(dynamicFormConfigResponse.model).toEqual(dynamicFormConfig.model, 'should return the form model formatted');
        expect(dynamicFormConfigResponse.form).toBeTruthy('should setup a FormGroup');
      });

    const req = httpTestingController.expectOne(testFormUrl);

    expect(req.request.method).toEqual('POST');
    req.flush(formSchema);
    httpTestingController.verify();
  });

  it('should submit the dynamic form value', () => {
    const dynamicFormModel = dynamicFormConfig.model;
    const resourceId = '123';

    service
      .submitForm$(dynamicFormModel, testFormUrl)
      .subscribe();

    const postReq = httpTestingController.expectOne(testFormUrl);

    expect(postReq.request.method).toEqual('POST', 'should create a new resource when no id is provided');
    expect(postReq.request.body.name).toEqual('Project 1', 'should upload the primitive values as they are');
    expect(postReq.request.body._links.parent).toEqual({ href: '/api/v3/projects/26' }, 'should format the resource values to only contain the href');

    postReq.flush('ok response');
    httpTestingController.verify();

    service
      .submitForm$(dynamicFormModel, testFormUrl, resourceId)
      .subscribe();

    const patchReq = httpTestingController.expectOne(`${testFormUrl}/${resourceId}`);

    expect(patchReq.request.method).toEqual('PATCH', 'should update the resource when an id is provided');

    patchReq.flush('ok response');
    httpTestingController.verify();
  });
});

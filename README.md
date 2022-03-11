# rhpam-pim-dynamic-instances
RH-PAM Process Instance migration startup customization repo

## repository content
the repo contains the following artifacts:

samples/openshift sample openshift yaml for creating 
- build config
  - pim-custom-bc.yaml - sample buildConfig for building the custom image from github
- configmaps
  - kieconfigs-7.12.0-dbs-pim_modified.yaml - sample kieconfig with LDAP configurations
- imageStream
  - pimserver-custom.yaml - sample ImageStream for build output
- KieApp
  - rhpam-pim-ldap.yaml - sample ldap configuration with wrapper for kie-servrs
  - rhpam-pim-oracle.yaml - sample oracle configuration with wrapper for kie-servrs

src contains every file needed for the customization
- bash contains the pimWrapper.sh script
- docker the Dockerfile for generating the image



### configuration

the wrapper uses the following system properties (to be specified inside KieApp)

#### custom kie-servers

| variable name | description | required |
|-------|-------|-------|
| KIE_SERVER_IMPORT_LIST | a comma separated list of KIE_SERVER name prefix for looking up kie-server configs (if ALL is specified then autodiscovery is enabled) | true |
| <KIE_SERVER_NAME>_KIESERVER_SERVICE_HOST | host name for the given kie-server | true if the kie server is not on the same project or the kie-app name is different | 
| <KIE_SERVER_NAME>_KIESERVER_SERVICE_PORT | listen port for the given kie-server | true if the kie server is not on the same project or the kie-app name is different | 
| <KIE_SERVER_NAME>_KIESERVER_USERNAME | username for the given kie-server | true | 
| <KIE_SERVER_NAME>_KIESERVER_PASSWORD | password for the given kie-server | true | 

for example:

~~~yaml 

      - name: KIE_SERVER_IMPORT_LIST
        value: ALL
      - name: RHPAM_KIESERVER1_KIESERVER_PASSWORD
        value: kieserver_password
      - name: RHPAM_KIESERVER1_KIESERVER_USERNAME
        value: adminUser
      - name: RHPAM_KIESERVER2_KIESERVER_PASSWORD
        value: kieserver_password2
      - name: RHPAM_KIESERVER2_KIESERVER_USERNAME
        value: adminUser
      - name: RHPAM_KIESERVER3_SERVICE_HOST
        value: kie-server3.anothernamespace.svc.cluster.local
      - name: RHPAM_KIESERVER3_KIESERVER_SERVICE_PORT
        value: '8080' 
      - name: RHPAM_KIESERVER3_KIESERVER_PASSWORD
        value: kieserver_password3
      - name: RHPAM_KIESERVER3_KIESERVER_USERNAME
        value: adminUser
  
~~~


#### custom LDAP configuration

in order to use the ldap authentication provider, the kieconfigs-7.12.x-pim-dbs configmap should be modified as follows:


edit the <database type>.yaml file where <database type> is the type selected in kie-app:
- external.yaml for external database type
- mysql.yaml for MySQL / MariaDB
- postgresql.yaml for postgreSQL

search for the application.yaml file section and insert the following informations inside the security : ldap section
~~~YAML

        ldap:
          realm-name:  pim-ldap
          enabled: true
          direct-verification: true
          dir-context:
            url: 'ldap://my-ldap.example.com:389'
            principal: 'uid=admin,ou=system'
            password: secret
          identity-mapping:
            rdn-identifier: uid
            search-base-dn: 'ou=people,o=SevenSeas'
            search-recursive: true
          attribute-mappings:
            "attribute-mappings":
              from: cn
              to: groups
              filter: 'uniquemember={1}'
              filter-base-dn: 'ou=groups,o=sevenSeas'       
~~~

Note:
dir-context parameters can be specified / overridden using the following environments inside kie-app using envitornment variables:

~~~YAML
      - name: QUARKUS_SECURITY_LDAP_DIR_CONTEXT_PASSWORD
        value: secret
      - name: QUARKUS_SECURITY_LDAP_DIR_CONTEXT_URL
        value: ldap://my-ldap.example.com:389
      - name: QUARKUS_SECURITY_LDAP_DIR_CONTEXT_PRINCIPAL
        value: uid=admin,ou=system
~~~

by default, pim app allows only one group to access the application: admin. In order to allow other LDAP groups to get authenticated on the application the following variable must be set:

~~~YAML

      - name: QUARKUS_HTTP_AUTH_POLICY_MAIN_POLICY_ROLES_ALLOWED
        value: LDAP GROUP 01,LDAP GROUP 02

~~~

finally, the pim authentication method should be switched from file(default) to LDAP.

~~~YAML

      - name: PIM_AUTH_METHOD
        value: ldap

~~~

the other authentication methods and related realms can be disabled:

~~~YAML

      - name: QUARKUS_SECURITY_USERS_FILE_ENABLED
        value: "false"
      - name: QUARKUS_SECURITY_JDBC_ENABLED
        value: "false"

~~~

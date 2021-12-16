#!/bin/bash
# this scripts is being provided as-is, without any form of support or warranty. 
# You can modify to fit your needs.

# Use the same logging as default scripts
source ${LAUNCH_DIR}/logging.sh


# required vars
# KIE_SERVER_IMPORT_LIST

#
function loadKieServerConfigs()
{
    # kie server user: <KS name>_KIESERVER_USERNAME
    # kie server password: <KS name>_KIESERVER_PASSWORD
    # kie server url: http://+<KS name>_KIESERVER_SERVICE_HOST + ":" + <KS name>_KIESERVER_SERVICE_PORT + "/services/rest/server"

    KieServerName=${1}
    KieServerSvcHostEnv=${KieServerName}_KIESERVER_SERVICE_HOST
    KieServerSvcPortEnv=${KieServerName}_KIESERVER_SERVICE_PORT
    KieServerUserEnv=${KieServerName}_KIESERVER_USERNAME
    KieServerPwdEnv=${KieServerName}_KIESERVER_PASSWORD

    if [[ -z "${!KieServerSvcHostEnv}" || -z "${!KieServerSvcPortEnv}" ]] ; then
        log_error "the service-related envs are not correctly configured, skipping ${KieServerName} configuration"
        echo -n ""
        return
    fi


    KieServerUrl=$(echo -n "http://${!KieServerSvcHostEnv}:${!KieServerSvcPortEnv}/services/rest/server")

    if [[ -z "${!KieServerUserEnv}" ]] ; then
        log_error "the variable named ${KieServerUserEnv} is not correctly configured, skipping ${KieServerName} configuration"
        echo -n ""
        return
    fi

    KieServerUser=${!KieServerUserEnv}
    
    if [[ -z "${!KieServerPwdEnv}" ]] ; then
        log_error "the variable named ${KieServerPwdEnv} is not correctly configured, skipping ${KieServerName} configuration"
        echo -n ""
        return
    fi

    KieServerPwd=${!KieServerPwdEnv}
    
    echo -n "-Dkieservers.${KIE_SERVER_INDEX}.host=${KieServerUrl} -Dkieservers.${KIE_SERVER_INDEX}.username=${KieServerUser} -Dkieservers.${KIE_SERVER_INDEX}.password=${KieServerPwd}"
}

if [[ -z "${KIE_SERVER_IMPORT_LIST}" ]] ; then
    log_warning "no KIE_SERVER_IMPORT_LIST var specified, skipping..."
else
    ServerList=$(echo -n ${KIE_SERVER_IMPORT_LIST} | tr "-" "_" | tr "[a-z]" "[A-Z]")

    if [[ "${ServerList}" =~ .*ALL.* ]]; then

        log_info "ALL is selected for import, retrieving kie_server list from env"
        ServerList=""
        for server in $(env | grep "KIESERVER_SERVICE_PORT=" | awk -F "_KIESERVER_SERVICE_PORT" '{print $1}' | sort) ; do #added sort for testing only
            ServerList="${ServerList} ${server}"
        done
    fi

    KIE_SERVER_INDEX=0
    JavaParameters=""
    for server in ${ServerList} ; do
        log_info "adding server ${server} with id ${KIE_SERVER_INDEX}"
        JavaParameters="${JavaParameters} $(loadKieServerConfigs ${server})"
        
        KIE_SERVER_INDEX=$(($KIE_SERVER_INDEX + 1))
    done

    log_info "Auto-configured for: ${ServerList}"

    log_info "removing kie-servers configured by the operator...."

    cat  ${JBOSS_KIE_EXTRA_CONFIG} | sed  -n '/thorntail:/,$p' > /tmp/thorntail_only_config.yaml
   # export JBOSS_KIE_EXTRA_CONFIG=/tmp/thorntail_only_config.yaml
fi

export JBOSS_KIE_EXTRA_CONFIG="${JBOSS_KIE_EXTRA_CONFIG} ${JavaParameters}"

/opt/rhpam-process-migration/openshift-launch.sh
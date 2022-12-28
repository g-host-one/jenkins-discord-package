def currentVersion = ""
def url = ""
def errorMsg = ""

def notifyTelegram(botKey, chatId, msg) {
    httpRequest formData: [[body: msg, name: 'text'], [body: chatId, name: 'chat_id'], [body: 'HTML', name: 'parse_mode']], url: 'https://api.telegram.org/bot' + botKey + '/sendMessage', httpMode: 'POST', responseHandle: 'NONE'
}

pipeline {
    agent any

    environment {
        telegramToken = credentials('telegramToken')
        chatId = credentials('chatId')
        ubuntuPgpKey = credentials('ubuntu_repo_pgp')
        PGP_KEY_NAME = 'Private Repo'
        GNUPGHOME = "${WORKSPACE_TMP}/pgp"
        REPO_DIR = '/mnt/repo/ubuntu/'
        REPO_CONF = '/etc/apt/ubuntu_repo.conf'
    }

    stages {
        stage('Setup parameters') {
            steps {
                script { 
                    properties([
                        parameters([
                            string(
                                defaultValue: '3', 
                                description: 'Max # of builds to keep with artifacts', 
                                name: 'pkgNumToKeep', 
                                trim: true
                            )
                        ])
                    ])
                }
            }
        }
        stage('Get current Discord version') {
            steps {
                script {
                    //def response = httpRequest url: 'https://discord.com/api/download?platform=linux', httpMode: 'HEAD', followRedirects: false
                    //if (response.headers["location"]?.size() == 1) {
                        //url = response.headers["location"][0]
                        url = sh(script: "curl -Is https://discord.com/api/download?platform=linux | grep -i 'location' | sed 's/location:\\(.*\\)/\\1/'", returnStdout: true).trim()
                        if (url ==~ /^http[s]?:\/\/.*/) {
                            def varsionMatch = (url =~ /([0-9\.]*)\.deb/)
                            if (varsionMatch.find()) {
                                currentVersion = varsionMatch.group(1)
                                if (currentVersion ==~ /^[0-9.]+$/) {
                                    println ("Current: " + currentVersion)
                                    println ("URL: " + url)
                                } else {
                                    errorMsg = "Failed to fetch current version"
                                }
                            } else {
                                errorMsg = "Failed to find current version"
                            }
                        } else {
                            errorMsg = "Failed to fetch url"
                        }
                    //} else {
                    //    errorMsg = "Failed to find url"
                    //}

                    if (errorMsg) {
                        currentBuild.result = 'FAILURE'
                        error(errorMsg)
                    }
                }
            }
        }
        stage ("Check version") {
            steps {
                script {
                    /*
                    [{"_class":"hudson.model.Cause$UserIdCause","shortDescription":"Started by user ***","userId":"***","userName":"***"}]
                    [{"_class":"hudson.triggers.TimerTrigger$TimerTriggerCause","shortDescription":"Started by timer"}]
                    [{"_class":"com.cloudbees.jenkins.GitHubPushCause","shortDescription":"Started by GitHub push by ***"}]
                    */

                    def isStartedByUser = currentBuild.getBuildCauses('hudson.model.Cause$UserIdCause')?.size() != 0
                    def isStartedByGit = currentBuild.getBuildCauses('com.cloudbees.jenkins.GitHubPushCause')?.size() != 0

                    if (isStartedByGit) {
                        def result = sh (script: "git log -1 | grep -Eoi '\\[skip ci\\]|\\[ci skip\\]'", returnStatus: true)
                        if (result == 0) {
                            isStartedByGit = false
                        }
                    }

                    if (!isStartedByUser && !isStartedByGit) {
                        def state = compareVersions (
                            v1: currentVersion,
                            v2: currentBuild.previousSuccessfulBuild.buildVariables.packageVersion,
                            failIfEmpty: false
                        )

                        switch(state) {
                            case 0:
                                currentBuild.result = 'ABORTED'
                                error("Latest build version is current one. Skipping build...")
                            break
                            case -1:
                                currentBuild.result = 'ABORTED'
                                error("The package was rolled back...")
                            break
                        }
                    }
                }
            }
        }
        stage ("Download package and add to repo") {
            steps {
                httpRequest outputFile: "${REPO_DIR}pool/main/d/discord/discord_${currentVersion}_amd64.deb", responseHandle: 'NONE', url: url, timeout: 5

                script {
                    if (params.pkgNumToKeep ==~ /^[0-9]+$/) {
                        int pkgNumToKeep = params.pkgNumToKeep as int

                        def files = findFiles(glob: '${REPO_DIR}pool/main/d/discord/discord_*_amd64.deb')
                        files.sort { it.name }

                        int pkgToRemove = files.size() - pkgNumToKeep

                        for (int i = 0; i < pkgToRemove; i++) {
                            sh("rm -rf ${files[i].path}")
                        }
                    }
                }

                sh './apt_repo_metadata_update.sh'
            }
        }
    }

    post {
        success {
            script {
                env.packageVersion = currentVersion
            }
            notifyTelegram(telegramToken, chatId, "<b><i>New Discord released!</i></b>\nVersion: ${currentVersion}")
        }
        failure {
            notifyTelegram(telegramToken, chatId, "<b>Discord build failed!</b>" + (errorMsg ? "\nError: ${errorMsg}" : ""))
        }
        always {
            dir(env.WORKSPACE_TMP) {
                deleteDir()
            }
        }
    }
}
node {
    try {
        repositories = ['Sunbird-Ed/SunbirdEd-portal',
                        'Sunbird-Ed/SunbirdEd-mobile',
                        'Sunbird-Ed/SunbirdEd-portal',
                        'Sunbird-Ed/SunbirdEd-mobile',
                        'project-sunbird/sunbird-lms-jobs',
                        'project-sunbird/sunbird-lms-service',
                        'project-sunbird/sunbird-data-pipeline',
                        'project-sunbird/sunbird-content-service'
                        ,'project-sunbird/sunbird-auth',
                        'project-sunbird/sunbird-learning-platform',
                        'project-sunbird/sunbird-content-plugins',
                        'project-sunbird/sunbird-lms-mw',
                        'project-sunbird/sunbird-ml-workbench',
                        'project-sunbird/sunbird-utils',
                        'project-sunbird/sunbird-analytics',
                        'project-sunbird/sunbird-telemetry-service',
                        'project-sunbird/secor',
                        'project-sunbird/sunbird-content-player',
                        'project-sunbird/sunbird-content-editor',
                        'project-sunbird/sunbird-content-plugins',
                        'project-sunbird/sunbird-collection-editor',
                        'project-sunbird/sunbird-generic-editor',
                        'project-sunbird/sunbird-devops']

        ansiColor('xterm') {
            String ANSI_GREEN = "\u001B[32m"
            String ANSI_NORMAL = "\u001B[0m"
            String ANSI_BOLD = "\u001B[1m"
            String ANSI_RED = "\u001B[31m"
            String ANSI_YELLOW = "\u001B[33m"


            if (params.size() == 0) {
                repoList = "['" + repositories.join("','") + "']"
                properties([[$class: 'RebuildSettings', autoRebuild: false, rebuildDisabled: false], parameters([[$class: 'CascadeChoiceParameter', choiceType: 'PT_CHECKBOX', description: '<font color=black size=2><b>Choose the repo to create tag</b></font>', name: '', filterLength: 1, filterable: false, name: 'repositories', randomName: 'choice-parameter-2927218175384999', referencedParameters: '', script: [$class: 'GroovyScript', fallbackScript: [classpath: [], sandbox: false, script: ''], script: [classpath: [], sandbox: false, script: """return $repoList """]]], [$class: 'DynamicReferenceParameter', choiceType: 'ET_FORMATTED_HTML', description: '<font color=black size=2><b>Choose the branch from which tag will be created</b></font>', name: 'release_branch', omitValueField: true, randomName: 'choice-parameter-2927218195310673', referencedParameters: '', script: [$class: 'GroovyScript', fallbackScript: [classpath: [], sandbox: false, script: ''], script: [classpath: [], sandbox: false, script: 'return """<input name="value" value="${public_repo_branch}" class="setting-input"  type="text">"""']]]]), [$class: 'ThrottleJobProperty', categories: [], limitOneJobWithMatchingParams: false, maxConcurrentPerNode: 0, maxConcurrentTotal: 0, paramsToUseForLimit: '', throttleEnabled: false, throttleOption: 'project']])
                println(ANSI_BOLD + ANSI_GREEN + "First run of the job. Parameters created. Stopping the current build. Please trigger new build and provide parameters" + ANSI_NORMAL)
                return
            }

            if (!params.release_branch.contains('release-') || params.release_branch == '') {
                println(ANSI_BOLD + ANSI_RED + "Uh oh! Release branch is not in valid format. Please provide value as release-" + ANSI_NORMAL)
                error 'Error: Release branch name format error'
            }

            if (params.repositories == '') {
                print(ANSI_BOLD + ANSI_RED + "Uh oh! No repositories are selected!" + ANSI_NORMAL)
                error 'No repositories selected'
            }

            stage('Create tag') {
                sh """
                        mkdir -p ${JENKINS_HOME}/public_release_tags
                        touch -a ${JENKINS_HOME}/public_release_tags/public_release_tags.txt
                    """
                cleanWs()
                releaseBranch = params.release_branch
                releaseVar = releaseBranch.split('-')[0]
                majorVar = releaseBranch.split('-')[1].split('\\.')[0]
                minorVar = releaseBranch.split('-')[1].split('\\.')[1]
                releaseBranch = releaseVar + "-" + majorVar + "." + minorVar

                params.repositories.split(',').each { repo ->
                    dir("$WORKSPACE") {
                        repo_name = repo.split('/')[1]
                        sh "git clone --depth 1 --no-single-branch https://github.com/$repo $repo_name"
                        dir("$repo_name") {
                            latestBranch = sh(returnStdout: true, script: "git ls-remote --exit-code --heads origin $releaseBranch* | awk -F \"/\" '{print \$3}' | sort -V -r | head -1").trim()
                            println latestBranch

                            if (latestBranch == '') {
                                println(ANSI_BOLD + ANSI_RED + params.release_branch + " branch and its patterns do not exists" + ANSI_NORMAL)
                                error 'Error: Release branch does not exists'
                            }

                            withCredentials([usernamePassword(credentialsId: env.githubPassword, passwordVariable: 'gitpass', usernameVariable: 'gituser')]) {
                                origin = "https://${gituser}:${gitpass}@" + sh(script: 'git config --get remote.origin.url', returnStdout: true).trim().split('https://')[1]
                                echo "Git Hash: ${origin}"
                                latestTag = sh(script: "git ls-remote --tags origin \"$releaseBranch*\" | grep -v \"RC\" | awk -F \"/\" '{print \$3}' | sort -V -r | grep ^release.*[0-9]\$ | head -1", returnStdout: true).trim()
                                println latestTag

                                if (latestTag == '') {
                                    branchLength = latestBranch.split('-')[1].split('\\.').length
                                    if (branchLength == 2) {
                                        println ANSI_BOLD + ANSI_YELLOW + "Branch is not in major.minor.patch format. Appending patch.." + ANSI_NORMAL
                                        latestAppendBranch = latestBranch + ".0"
                                        println latestAppendBranch
                                    }
                                    sh("git push ${origin} refs/remotes/origin/$latestBranch:refs/tags/$latestAppendBranch")
                                }
                                else {
                                    println(ANSI_BOLD + ANSI_GREEN + "Remote has same tag name. Incrementing and creating tag!" + ANSI_NORMAL)

                                    tagLength = latestTag.split('-')[1].split('\\.').length
                                    if (tagLength == 2) {
                                        println ANSI_BOLD + ANSI_YELLOW + "Tag is not in major.minor.patch format. Appending patch.." + ANSI_NORMAL
                                        latestTag = latestTag + ".0"
                                        println latestTag
                                    }

                                    releaseVar = latestTag.split('-')[0]
                                    majorVar = latestTag.split('-')[1].split('\\.')[0]
                                    minorVar = latestTag.split('-')[1].split('\\.')[1]
                                    patchVar = latestTag.split('-')[1].split('\\.')[2]
                                    patchVar = patchVar.toInteger() + 1
                                    tagToPush = releaseVar + "-" + majorVar + "." + minorVar + "." + patchVar
                                    println tagToPush
                                    sh("git push ${origin} refs/remotes/origin/$latestBranch:refs/tags/$tagToPush")
                                    latestTag = tagToPush
                                }
                            }
                            sh """
                                      sed -i "s/${repo_name}.*//g" ${JENKINS_HOME}/public_release_tags/public_release_tags.txt
                                      sed -i "/^\\\$/d" ${JENKINS_HOME}/public_release_tags/public_release_tags.txt
                                      echo "$repo_name : $latestTag" >> ${JENKINS_HOME}/public_release_tags/public_release_tags.txt
                                 """
                        }
                    }
                }
            }
            stage('Archive artifacts') {
                sh "cp ${JENKINS_HOME}/public_release_tags/public_release_tags.txt ."
                sh "sort public_release_tags.txt -o public_release_tags.txt && cat public_release_tags.txt"
                archiveArtifacts artifacts: 'public_release_tags.txt', fingerprint: true
            }
        }
    }

    catch (err) {
        throw err
    }
}

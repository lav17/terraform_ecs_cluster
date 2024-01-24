pipeline {
    agent any

    environment {
        TF_VAR_CLOUDFRONT_IP = credentials('TF_VAR_CLOUDFRONT_IP')
        AWS_ACCESS_KEY_ID = credentials('f69d8b70-3d94-4abe-90c8-9cb608f1a66b')
        AWS_SECRET_ACCESS_KEY = credentials('f69d8b70-3d94-4abe-90c8-9cb608f1a66b')
    }

    stages {
        stage('Build project') {
            steps {
                git branch: 'master', url: 'https://github.com/lav17/terraform_ecs_cluster.git'
            }
        }

        stage('Terraform Init') {
            steps {
                
                    script {
                        bat """
                            terraform init \
                                -var AWS_ACCESS_KEY_ID=${env.AWS_ACCESS_KEY_ID} \
                                -var AWS_SECRET_ACCESS_KEY=${env.AWS_SECRET_ACCESS_KEY} \
                                -var TF_VAR_CLOUDFRONT_IP=${env.TF_VAR_CLOUDFRONT_IP}  \
                                -input=false
                        """
                    }
             }
        }
        

        stage('Terraform Apply') {
            steps {
                
                    script {
                        bat """
                            terraform apply \
                                -var AWS_ACCESS_KEY_ID=${env.AWS_ACCESS_KEY_ID} \
                                -var AWS_SECRET_ACCESS_KEY=${env.AWS_SECRET_ACCESS_KEY} \
                                -var TF_VAR_CLOUDFRONT_IP=${env.TF_VAR_CLOUDFRONT_IP} \
                                -auto-approve
                        """
                    }
                }
       }


               
    }
}

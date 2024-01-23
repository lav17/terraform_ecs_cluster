pipeline {
    agent any

    environment {
        TF_VAR_CLOUDFRONT_IP = credentials('TF_VAR_CLOUDFRONT_IP')
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
                                -var TF_VAR_CLOUDFRONT_IP=${env.TF_VAR_CLOUDFRONT_IP} \
                                -auto-approve
                        """
                    }
                }
       }

       stage('Terraform Destroy') {
            steps {
                
                    script {
                        bat """
                            terraform destroy \
                                -var TF_VAR_CLOUDFRONT_IP=${env.TF_VAR_CLOUDFRONT_IP} \
                                -auto-approve
                        """
                    }
                }
           }
        
    }
}


sudo docker container stop sshnp_test_sshnp
sudo docker container stop sshnp_test_sshnpd
sudo docker container stop sshnp_test_sshrvd

sudo docker container rm sshnp_test_sshnp
sudo docker container rm sshnp_test_sshnpd
sudo docker container rm sshnp_test_sshrvd

sudo docker network rm sshnp_test_sshnp_network
sudo docker network rm sshnp_test_sshnpd_network
sudo docker network rm sshnp_test_sshrvd_network

sudo docker image rm atsigncompany/sshnp_test_base
sudo docker image rm atsigncompany/sshnp_test_sshnp
sudo docker image rm atsigncompany/sshnp_test_sshnpd
sudo docker image rm atsigncompany/sshnp_test_sshrvd

echo Done cleaning!
# Docker

1. Update the `apt` package index and install packages to allow `apt` to use a repository over HTTPS:

    ```shell
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    ```

2. Add Docker’s official GPG key:

    ```shell
    curl -fsSL https://mirror.sjtu.edu.cn/docker-ce/linux/ubuntu/gpg | sudo apt-key add –
    ```

3. Use the following command to set up the **stable** repository.

    ```shell
    sudo apt-get install -y software-properties-common
    sudo add-apt-repository "deb [arch=amd64] https://mirror.sjtu.edu.cn/docker-ce/linux/ubuntu/  $(lsb_release -cs)  stable" 
    ```

4. INSTALL DOCKER ENGINE

    ```shell
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io
    ```

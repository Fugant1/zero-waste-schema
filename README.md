# zero-waste-schema
Relational schema for a surplus redistribution platform, connecting establishments with beneficiaries to eliminate food waste.

## Prerequisites
Before you begin, ensure you have the following installed on your system:
* **[Docker](https://docs.docker.com/get-docker/)**: Required to run the isolated Oracle Database container.
* **Bash**: The standard terminal environment (Native to Linux/macOS. Windows users can use WSL).

## How to run
### Configure your Enviroment
Create a file named `.env` in the `src` folder:
```env
# File: src/.env
SENHA_BD=your_secure_oracle_password
```
### Run and populate db
Just run the script to start the database and populate it automatically to test the functionality:
```
# In terminal
cd src
chmod +x run.sh
sudo ./run.sh
```

### Stop and delete the db
The database will run in the background on port 1521. If you want to turn it off or completely remove it from your system, you can use the following Docker commands:

To stop the database (turns the server off but keeps your data saved):
```
sudo docker stop bd-oracle
```

To delete the container completely (wipes the database and resets the environment):
```
sudo docker rm -f bd-oracle
```
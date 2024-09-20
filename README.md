## Salary payment

Salary payment is an app to manage salary payment which works in aptos network. These are the instructions to run the app:

1. create the .env file in the root directory with the next env vars:

```cmd
PROJECT_NAME=salary_payment
VITE_APP_NETWORK=[NETWORK OF THE APP TESNET or MAINNET]
VITE_MODULE_ADDRESS=[YOU ADDRESS ACCOUNT WHERE THE CONTRACT WILL BE DEPLOYED]]
```

2. Install modules:

```cmd
yarn
```

3. Publish the contract:

```cmd
yarn salary-payment:compile && yarn salary-payment:publish
```

4. Run the app:

```cmd
yarn dev
```

5. Go to the link that is shown in the terminal and in the web click in `create resource account` button
7. Fund the address showing after creating the resource account
8. Now you can start add employees
9. Employees need to subscribe to the payment to start receiving salarys clicking in `subscribe`
10. After they subscribe, you can fill the salary amount of each employee and click in `payment` button to pay them
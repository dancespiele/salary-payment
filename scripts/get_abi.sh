#! /bin/bash
 
# replace it with the network your contract lives on
NETWORK=testnet
# replace it with your contract address
CONTRACT_ADDRESS="0x1cdcbae7369dc8e159bc8bf951cfb7e7e168ef1bd56c169dcacb336b13657417"
# replace it with your module name, every .move file except move script has module_address::module_name {}
MODULE_NAME=payment
 
# save the ABI to a TypeScript file
echo "export const ABI = $(curl https://fullnode.$NETWORK.aptoslabs.com/v1/accounts/$CONTRACT_ADDRESS/module/$MODULE_NAME | sed -n 's/.*"abi":\({.*}\).*}$/\1/p') as const" > abi.ts
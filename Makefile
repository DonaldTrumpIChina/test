.PHONY: start compile

all: start compile

start :; npm install --save-dev hardhat

compile :; npx hardhat compile
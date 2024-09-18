require("dotenv").config();
const fs = require("node:fs");
const yaml = require("js-yaml");
const cli = require("@aptos-labs/ts-sdk/dist/common/cli/index.js");

const config = yaml.load(fs.readFileSync("./.aptos/config.yaml", "utf8"));
const accountAddress =
  config["profiles"][`salary_payment_${process.env.VITE_APP_NETWORK}`]["account"];

async function publish() {
  const move = new cli.Move();

  await move.publish({
    packageDirectoryPath: "salary_payment",
    namedAddresses: {
      salary_addr: accountAddress,
    },
    profile: `salary_payment_${process.env.VITE_APP_NETWORK}`
  });
}
publish();

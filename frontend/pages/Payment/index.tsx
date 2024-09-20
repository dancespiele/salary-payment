import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useEffect, useState } from "react";
import { Socials } from "./components/Socials";

import { Header } from "@/components/Header";
import { useAbiClient } from "@/context/AbiProvider";
import { SalaryPaymentAbi } from "@/abis/SalaryPaymentAbi";
import { Button } from "@/components/ui/button";
import { useWalletClient } from "@thalalabs/surf/hooks";
import { toast } from "@/components/ui/use-toast";
import { Admin } from "./components/Admin";
import { convertAmountFromOnChainToHumanReadable } from "@/utils/helpers";

export function Payment() {
  const { account, connected } = useWallet();
  const { client } = useWalletClient();
  const { abi } = useAbiClient();
  const [isAdmin, setIsAdmin] = useState<boolean>(false);
  const [isEmployee, setIsEmployee] = useState<boolean>(false);
  const [isSubscribed, setIsSubscribed] = useState<boolean>(false);
  const [balanceToClaim, setBalanceToClaim] = useState<number>();

  const onClaim = async () => {
    try {
      const tx = await client?.useABI(SalaryPaymentAbi).claim_salary({
        type_arguments: ["0x1::aptos_coin::AptosCoin"],
        arguments: [],
      });

      setBalanceToClaim(0);

      toast({
        title: "Claimed",
        description: `${tx?.hash}`,
        variant: "default",
      });
    } catch (e) {
      toast({
        title: "Error to claim salary",
        description: `${e}`,
        variant: "destructive",
      });
    }
  };

  const onSubscribe = async () => {
    try {
      const tx = await client?.useABI(SalaryPaymentAbi).create_employee_object({
        type_arguments: [],
        arguments: [],
      });

      setIsSubscribed(true);

      toast({
        title: "Subscribed",
        description: `${tx?.hash}`,
        variant: "default",
      });
    } catch (e) {
      console.error(e);
      toast({
        title: "Error subscribing to payment",
        description: `${e}`,
        variant: "destructive",
      });
    }
  };

  useEffect(() => {
    if (!connected) return;
    void (async () => {
      const admins = await abi?.useABI(SalaryPaymentAbi).view.get_admin({
        typeArguments: [],
        functionArguments: [],
      });
      setIsAdmin(Boolean(admins?.some((a) => a === account?.address)));
    })();
  }, [connected, account?.address, abi]);

  useEffect(() => {
    if (!connected) return;
    void (async () => {
      const response = await abi?.useABI(SalaryPaymentAbi).view.get_employees({
        typeArguments: [],
        functionArguments: [],
      });

      const employeefound = Boolean(response?.[0]?.some((a) => a === account?.address));

      setIsEmployee(employeefound);
    })();
  }, [abi, account, connected]);

  useEffect(() => {
    if (!isEmployee) return;
    void (async () => {
      const responseSubs = await abi?.useABI(SalaryPaymentAbi).view.check_employee_object({
        typeArguments: [],
        functionArguments: [account?.address as `0x${string}`],
      });

      const subscriptionFound = Boolean(responseSubs?.[0]);

      setIsSubscribed(subscriptionFound);

      if (subscriptionFound) {
        const responseBalance = await abi?.useABI(SalaryPaymentAbi).view.get_balance_to_claim({
          typeArguments: [],
          functionArguments: [account?.address as `0x${string}`],
        });

        const balanceFound = responseBalance?.[0];

        setBalanceToClaim(convertAmountFromOnChainToHumanReadable(Number(balanceFound), 8));
      }
    })();
  }, [isEmployee, abi]);

  return (
    <>
      <Header />
      <div style={{ overflow: "hidden" }} className="overflow-hidden">
        {isAdmin && <Admin />}
        {isEmployee ? (
          <>
            {isSubscribed ? (
              <>
                <div className="m-10">
                  <span className="mr-10 text-center text-3xl font-bold">Balance to claim: {balanceToClaim}</span>
                  <Button variant="green" onClick={onClaim} disabled={balanceToClaim === 0}>
                    Claim
                  </Button>
                </div>
              </>
            ) : (
              <>
                <div className="m-10">
                  <p>Subscribe to get your salary</p>
                  <Button variant="default" onClick={onSubscribe}>
                    Subscribe
                  </Button>
                </div>
              </>
            )}
          </>
        ) : (
          <>{!isAdmin && <h3>You are not a employee of this company</h3>}</>
        )}
        <footer className="footer-container px-4 pb-6 w-full max-w-screen-xl mx-auto mt-6 md:mt-16 flex items-center justify-between">
          <Socials />
        </footer>
      </div>
    </>
  );
}

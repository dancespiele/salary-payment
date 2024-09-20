import { SalaryPaymentAbi } from "@/abis/SalaryPaymentAbi";
import { LabeledInput } from "@/components/ui/labeled-input";
import { toast } from "@/components/ui/use-toast";
import { useAbiClient } from "@/context/AbiProvider";
import { useWallet } from "@aptos-labs/wallet-adapter-react";
import { useWalletClient } from "@thalalabs/surf/hooks";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { convertAmountFromHumanReadableToOnChain, convertAmountFromOnChainToHumanReadable } from "@/utils/helpers";

export const Admin = () => {
  const { abi } = useAbiClient();
  const [newAddress, setNewAddress] = useState<`0x${string}`>();
  const [isResourceAccountSet, setIsResourceAccountSet] = useState<boolean>(false);
  const [resourceAccount, setResourceAccount] = useState("");
  const [employeesSubscribed, setEmployeesSubscribed] = useState<`0x${string}`[]>([]);
  const [employeesNotSubscribed, setEmployeesNotSubscribed] = useState<`0x${string}`[]>([]);
  const [salaries, setSalaries] = useState<number[]>([]);
  const [resourceAccountBalance, setResourceAccountBalance] = useState<number>(0);
  const { connected } = useWallet();
  const { client } = useWalletClient();

  useEffect(() => {
    if (isResourceAccountSet) {
      void (async () => {
        const response = await abi?.useABI(SalaryPaymentAbi).view.get_resource_account_address({
          typeArguments: [],
          functionArguments: [],
        });

        setResourceAccount(response?.[0] as string);

        const balance = await abi?.useABI(SalaryPaymentAbi).view.get_resource_balance({
          typeArguments: ["0x1::aptos_coin::AptosCoin"],
          functionArguments: [],
        });

        setResourceAccountBalance(convertAmountFromOnChainToHumanReadable(Number(balance?.[0]), 8));
      })();
    }
    void (async () => {
      const resourceAccountExists = await abi?.useABI(SalaryPaymentAbi).view.resource_account_exists({
        typeArguments: [],
        functionArguments: [],
      });

      setIsResourceAccountSet(Boolean(resourceAccountExists?.[0]));
    })();
  }, [isResourceAccountSet, abi]);

  useEffect(() => {
    void (async () => {
      const addresses = await abi?.useABI(SalaryPaymentAbi).view.get_employees({
        typeArguments: [],
        functionArguments: [],
      });

      const subscribers = await Promise.all(
        addresses?.[0].map(async (a) => {
          const isSubscriber = await abi?.useABI(SalaryPaymentAbi).view.check_employee_object({
            typeArguments: [],
            functionArguments: [a],
          });

          return Boolean(isSubscriber?.[0]);
        }) || [],
      );

      setEmployeesSubscribed([...(addresses?.[0]?.filter((_a, i) => subscribers[i]) as `0x${string}`[])]);

      setEmployeesNotSubscribed([...(addresses?.[0]?.filter((_a, i) => !subscribers[i]) as `0x${string}`[])]);
    })();
  }, [abi]);

  const onAdd = async () => {
    if (!connected) {
      return;
    }

    try {
      const tx = await client?.useABI(SalaryPaymentAbi).add_employee({
        type_arguments: [],
        arguments: [newAddress as `0x${string}`],
      });

      setEmployeesNotSubscribed([...employeesNotSubscribed, newAddress as `0x${string}`]);
      setNewAddress(undefined);

      toast({
        title: "Added employee",
        description: `${tx?.hash}`,
        variant: "default",
      });
    } catch (error) {
      toast({
        title: "Error adding employee",
        description: `${error}`,
        variant: "destructive",
      });
    }
  };

  const onRemoveEmployee = async (employee: `0x${string}`) => {
    try {
      const tx = await client?.useABI(SalaryPaymentAbi).remove_employee({
        type_arguments: [],
        arguments: [employee],
      });

      setEmployeesNotSubscribed(employeesNotSubscribed.filter((e) => e !== employee));
      setEmployeesSubscribed(employeesSubscribed.filter((e) => e !== employee));

      toast({
        title: "Removed employee",
        description: `${tx?.hash}`,
        variant: "default",
      });
    } catch (error) {
      toast({
        title: "Error removing employee",
        description: `${error}`,
        variant: "destructive",
      });
    }
  };

  const onAddSalary = (salary: number, employee: number) => {
    const salariesCopy = [...salaries];

    salariesCopy[employee] = salary;

    setSalaries([...salariesCopy]);
  };

  const onCreateResourceAccount = async () => {
    if (!connected) {
      return;
    }

    try {
      const tx = await client?.useABI(SalaryPaymentAbi).create_resource_account({
        type_arguments: [],
        arguments: ["aptostest@gmail.com", []],
      });

      toast({
        title: "Created resource account",
        description: `${tx?.hash}`,
        variant: "default",
      });
    } catch (error) {
      toast({
        title: "Error creating resource account",
        description: `${error}`,
        variant: "destructive",
      });
    }
  };

  const onPayEmployees = async () => {
    try {
      const tx = await client?.useABI(SalaryPaymentAbi).payment({
        type_arguments: ["0x1::aptos_coin::AptosCoin"],
        arguments: [[...employeesSubscribed], [...salaries.map((s) => convertAmountFromHumanReadableToOnChain(s, 8))]],
      });

      toast({
        title: "Paid employees",
        description: `${tx?.hash}`,
        variant: "default",
      });

      setSalaries([...employeesSubscribed.map(() => 0)]);
    } catch (error) {
      toast({
        title: "Error paying employees",
        description: `${error}`,
        variant: "destructive",
      });
    }
  };

  return (
    <div className="mt-10">
      {isResourceAccountSet ? (
        <>
          <div className="w-4/6 m-2">
            <div>Account Address: {resourceAccount}</div>
            <div>Balance: {resourceAccountBalance}</div>
          </div>
          <div className="w-4/6 m-2">
            <LabeledInput
              id="employee-address"
              label="Address"
              tooltip="The wallet address of the employee"
              required={true}
              value={newAddress}
              onChange={(e) => setNewAddress(e.target.value as `0x${string}`)}
              type="text"
            />
          </div>
          <div className="w-1/6 m-2 self-end mb-10">
            <Button variant="default" onClick={onAdd} disabled={!newAddress}>
              Add
            </Button>
          </div>
          <div className="w-4/6 m-2">
            {Boolean(employeesNotSubscribed.length) && <h3>Employees no subscribed yet:</h3>}
            {employeesNotSubscribed.map((e, i) => (
              <div className="mt-5" key={`${i}-${e}`}>
                <div>
                  Employee {i + 1}: {e}
                </div>
                <Button className="mt-5" onClick={() => onRemoveEmployee(e)} variant="destructive">
                  Remove Employee
                </Button>
              </div>
            ))}
            {Boolean(employeesSubscribed.length) && (
              <h3 className="mt-10">Employees subscribed to the resource account:</h3>
            )}
            {employeesSubscribed.map((e, i) => (
              <div className="mt-5" key={`${i}-${e}`}>
                <div>
                  Employee {i + 1}: {e}
                </div>
                <LabeledInput
                  id="employee-salary"
                  label="Salary"
                  tooltip="The salary to pay to the employee"
                  required={true}
                  value={salaries[i]}
                  onChange={(e) => onAddSalary(Number(e.target.value), i)}
                  type="number"
                />
                <Button className="mt-5" onClick={() => onRemoveEmployee(e)} variant="destructive">
                  Remove Employee
                </Button>
              </div>
            ))}
            <Button className="mt-10" variant="default" onClick={onPayEmployees} disabled={!employeesSubscribed.length}>
              Pay employees
            </Button>
          </div>
        </>
      ) : (
        <>
          <div className="w-1/6 m-2 self-end">
            <Button variant="default" onClick={onCreateResourceAccount}>
              Create resource account
            </Button>
          </div>
        </>
      )}
    </div>
  );
};

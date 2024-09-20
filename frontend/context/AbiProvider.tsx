"use client";
import { createSurfClient, DefaultABITable } from "@thalalabs/surf";
import { createContext, ReactNode, useContext, useEffect, useState } from "react";
import { Aptos, AptosConfig, Network } from "@aptos-labs/ts-sdk";
import { Client } from "node_modules/@thalalabs/surf/build/types/core/Client";

export type AbiContextProp = {
  abi: Client<DefaultABITable> | undefined;
};

const AbiContext = createContext<AbiContextProp>({} as AbiContextProp);

export const AbiProvider = ({ children }: { children: ReactNode }) => {
  const [abi, setAbi] = useState<Client<DefaultABITable>>();

  useEffect(() => {
    const aptos = new Aptos(
      new AptosConfig({ network: process.env.VITE_APP_NETWORK === "mainnet" ? Network.MAINNET : Network.TESTNET }),
    );

    const surfClient = createSurfClient(aptos);

    setAbi(surfClient);
  }, []);

  const values = { abi };

  return <AbiContext.Provider value={values}>{children}</AbiContext.Provider>;
};

export const useAbiClient = () => {
  return useContext(AbiContext);
};

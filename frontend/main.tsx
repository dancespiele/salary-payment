import "./index.css";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import React from "react";
import ReactDOM from "react-dom/client";

import App from "@/App";
import { WalletProvider } from "@/components/WalletProvider";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AbiProvider } from "./context/AbiProvider";

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <WalletProvider>
      <AbiProvider>
        <QueryClientProvider client={queryClient}>
          <TooltipProvider delayDuration={100}>
            <App />
            <Toaster />
          </TooltipProvider>
        </QueryClientProvider>
      </AbiProvider>
    </WalletProvider>
  </React.StrictMode>,
);

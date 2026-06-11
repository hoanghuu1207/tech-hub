"use client";

import { usePathname } from "next/navigation";
import { SidebarTrigger } from "@/components/ui/sidebar";
import { Separator } from "@/components/ui/separator";
import { MENU_ITEMS } from "@/lib/constants";

export function AppHeader() {
  const pathname = usePathname();

  // Find current page title from menu items
  const currentItem = MENU_ITEMS.find(
    (item) => pathname === item.href || pathname.startsWith(item.href + "/")
  );
  const pageTitle = currentItem?.title || "Admin";

  return (
    <header className="flex h-14 shrink-0 items-center gap-2 border-b px-4 bg-background/80 backdrop-blur-sm sticky top-0 z-30">
      <SidebarTrigger className="-ml-1" />
      <Separator orientation="vertical" className="mr-2 !h-4" />
      <h1 className="text-sm font-semibold">{pageTitle}</h1>
    </header>
  );
}

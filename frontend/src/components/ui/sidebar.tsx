import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { PanelLeft } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent } from "@/components/ui/sheet";

type SidebarContextValue = { state: "expanded" | "collapsed"; toggleSidebar: () => void };
const SidebarContext = React.createContext<SidebarContextValue | null>(null);

function useSidebar() {
  const context = React.useContext(SidebarContext);
  if (!context) throw new Error("useSidebar must be used within a SidebarProvider.");
  return context;
}

const SidebarProvider = React.forwardRef<HTMLDivElement, React.ComponentProps<"div"> & { defaultOpen?: boolean }>(
  ({ className, style, children, defaultOpen = true, ...props }, ref) => {
    const [open, setOpen] = React.useState(defaultOpen);
    const toggleSidebar = React.useCallback(() => setOpen((o) => !o), []);
    return (
      <SidebarContext.Provider value={{ state: open ? "expanded" : "collapsed", toggleSidebar }}>
        <div ref={ref} data-state={open ? "expanded" : "collapsed"} style={style}
          className={cn("flex min-h-screen w-full", className)} {...props}>{children}</div>
      </SidebarContext.Provider>
    );
  }
);
SidebarProvider.displayName = "SidebarProvider";

const SidebarTrigger = React.forwardRef<React.ElementRef<typeof Button>, React.ComponentProps<typeof Button>>(
  ({ className, onClick, ...props }, ref) => {
    const { toggleSidebar } = useSidebar();
    return (
      <Button ref={ref} data-sidebar="trigger" variant="ghost" size="icon" className={cn("h-7 w-7", className)}
        onClick={(e) => { onClick?.(e); toggleSidebar(); }} {...props}>
        <PanelLeft /><span className="sr-only">Toggle Sidebar</span>
      </Button>
    );
  }
);
SidebarTrigger.displayName = "SidebarTrigger";

const Sidebar = React.forwardRef<HTMLDivElement, React.ComponentProps<"aside"> & { side?: "left" | "right"; collapsible?: "offcanvas" | "icon" | "none" }>(
  ({ className, children, side = "left", collapsible = "offcanvas", ...props }, ref) => {
    const { state } = useSidebar();
    if (collapsible === "none") {
      return (<div ref={ref} className={cn("flex h-full w-[--sidebar-width] flex-col bg-background text-foreground", className)} {...props}>{children}</div>);
    }
    return (
      <Sheet>
        <div ref={ref} data-sidebar="sidebar" data-side={side}
          className={cn("hidden h-screen w-64 shrink-0 border-r bg-background transition-all md:block",
            state === "collapsed" && "w-16", className)} {...props}>
          {children}
        </div>
        <SheetContent side={side} className="w-64 p-0 md:hidden">{children}</SheetContent>
      </Sheet>
    );
  }
);
Sidebar.displayName = "Sidebar";

const SidebarHeader = React.forwardRef<HTMLDivElement, React.ComponentProps<"div">>(
  ({ className, ...props }, ref) => (<div ref={ref} className={cn("flex flex-col gap-2 p-2", className)} {...props} />));
SidebarHeader.displayName = "SidebarHeader";

const SidebarFooter = React.forwardRef<HTMLDivElement, React.ComponentProps<"div">>(
  ({ className, ...props }, ref) => (<div ref={ref} className={cn("flex flex-col gap-2 p-2 mt-auto", className)} {...props} />));
SidebarFooter.displayName = "SidebarFooter";

const SidebarContent = React.forwardRef<HTMLDivElement, React.ComponentProps<"div">>(
  ({ className, ...props }, ref) => (<div ref={ref} className={cn("flex min-h-0 flex-1 flex-col gap-2 overflow-auto", className)} {...props} />));
SidebarContent.displayName = "SidebarContent";

const SidebarGroup = React.forwardRef<HTMLDivElement, React.ComponentProps<"div">>(
  ({ className, ...props }, ref) => (<div ref={ref} className={cn("relative flex w-full min-w-0 flex-col p-2", className)} {...props} />));
SidebarGroup.displayName = "SidebarGroup";

const SidebarMenu = React.forwardRef<HTMLUListElement, React.ComponentProps<"ul">>(
  ({ className, ...props }, ref) => (<ul ref={ref} className={cn("flex w-full min-w-0 flex-col gap-1", className)} {...props} />));
SidebarMenu.displayName = "SidebarMenu";

const SidebarMenuItem = React.forwardRef<HTMLLIElement, React.ComponentProps<"li">>(
  ({ className, ...props }, ref) => (<li ref={ref} className={cn("group/menu-item relative", className)} {...props} />));
SidebarMenuItem.displayName = "SidebarMenuItem";

const SidebarMenuButton = React.forwardRef<HTMLButtonElement, React.ComponentProps<"button"> & { asChild?: boolean; isActive?: boolean; tooltip?: string }>(
  ({ asChild = false, isActive = false, className, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp ref={ref} data-sidebar="menu-button" data-active={isActive}
        className={cn("flex w-full min-w-0 cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 text-sm outline-none transition-colors hover:bg-accent aria-expanded:bg-accent data-[active=true]:bg-accent", className)}
        {...props} />
    );
  }
);
SidebarMenuButton.displayName = "SidebarMenuButton";

export {
  Sidebar, SidebarContent, SidebarFooter, SidebarGroup, SidebarHeader, SidebarMenu, SidebarMenuButton,
  SidebarMenuItem, SidebarProvider, SidebarTrigger, useSidebar,
};

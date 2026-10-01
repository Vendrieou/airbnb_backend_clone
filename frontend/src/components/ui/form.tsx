import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { Label, type LabelProps } from "@radix-ui/react-label";
import { cn } from "@/lib/utils";

const FormFieldContext = React.createContext<{ id: string }>({ id: "" });

interface FormProps extends React.FormHTMLAttributes<HTMLFormElement> {
  onSubmit?: (e: React.FormEvent<HTMLFormElement>) => void;
}

const Form = ({ onSubmit, ...props }: FormProps) => (
  <form noValidate {...props} onSubmit={(e) => {
    const data = new FormData(e.currentTarget);
    e.currentTarget.dispatchEvent(new CustomEvent("formdata", { detail: data }));
    onSubmit?.(e);
  }} />
);

type FormFieldProps = { name: string; children: React.ReactNode };
const FormField = ({ name, children }: FormFieldProps) => (
  <FormFieldContext.Provider value={{ id: `f-${name}` }}>{children}</FormFieldContext.Provider>
);

const useFormField = () => {
  const ctx = React.useContext(FormFieldContext);
  return { id: ctx.id, name: ctx.id.replace(/^f-/, "") };
};

const FormItem = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (<div ref={ref} className={cn("space-y-2", className)} {...props} />)
);
FormItem.displayName = "FormItem";

const FormLabel = React.forwardRef<React.ElementRef<typeof Label>, LabelProps>(
  ({ className, htmlFor, ...props }, ref) => {
    const { id } = useFormField();
    return <Label ref={ref} className={cn(className)} htmlFor={htmlFor ?? id} {...props} />;
  }
);
FormLabel.displayName = "FormLabel";

const FormControl = React.forwardRef<React.ElementRef<typeof Slot>, React.ComponentPropsWithoutRef<typeof Slot>>(
  ({ ...props }, ref) => {
    const { id } = useFormField();
    return <Slot ref={ref} id={id} aria-describedby={`${id}-desc`} {...props} />;
  }
);
FormControl.displayName = "FormControl";

const FormDescription = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLParagraphElement>>(
  ({ className, ...props }, ref) => {
    const { id } = useFormField();
    return <p ref={ref} id={`${id}-desc`} className={cn("text-sm text-muted-foreground", className)} {...props} />;
  }
);
FormDescription.displayName = "FormDescription";

const FormMessage = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLParagraphElement>>(
  ({ className, children, ...props }, ref) => {
    if (!children) return null;
    return <p ref={ref} role="alert" className={cn("text-sm font-medium text-destructive", className)} {...props}>{children}</p>;
  }
);
FormMessage.displayName = "FormMessage";

export { Form, FormField, FormItem, FormLabel, FormControl, FormDescription, FormMessage, useFormField };

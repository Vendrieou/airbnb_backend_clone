import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import useEmblaCarousel, { type UseEmblaCarouselType } from "embla-carousel-react";
import { ArrowLeft, ArrowRight } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

type CarouselApi = UseEmblaCarouselType[1];
type UseCarouselParameters = Parameters<typeof useEmblaCarousel>;
type CarouselOptions = UseCarouselParameters[0];
type CarouselPlugin = UseCarouselParameters[1];

type CarouselProps = { opts?: CarouselOptions; plugins?: CarouselPlugin; orientation?: "horizontal" | "vertical"; setApi?: (api: CarouselApi) => void };

const CarouselContext = React.createContext<{ carouselRef: ReturnType<typeof useEmblaCarousel>[0]; api: NonNullable<CarouselApi>; scrollPrev: () => void; scrollNext: () => void; canScrollPrev: boolean; canScrollNext: boolean } & CarouselProps>(null as any);

function useCarousel() {
  const context = React.useContext(CarouselContext);
  if (!context) throw new Error("useCarousel must be used within a <Carousel />");
  return context;
}

const Carousel = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement> & CarouselProps>(
  ({ orientation = "horizontal", opts, setApi, plugins, className, children, ...props }, ref) => {
    const [carouselRef, api] = useEmblaCarousel({ ...opts, axis: orientation === "horizontal" ? "x" : "y" }, plugins);
    const [canScrollPrev, setCanScrollPrev] = React.useState(false);
    const [canScrollNext, setCanScrollNext] = React.useState(false);
    const onSelect = React.useCallback((api: CarouselApi) => {
      if (!api) return;
      setCanScrollPrev(api.canScrollPrev());
      setCanScrollNext(api.canScrollNext());
    }, []);
    const scrollPrev = React.useCallback(() => api?.scrollPrev(), [api]);
    const scrollNext = React.useCallback(() => api?.scrollNext(), [api]);
    React.useEffect(() => {
      if (!api || !setApi) return;
      setApi(api);
    }, [api, setApi]);
    React.useEffect(() => {
      if (!api) return;
      onSelect(api);
      api.on("reInit", onSelect).on("select", onSelect);
      return () => { api?.off("select", onSelect); };
    }, [api, onSelect]);
    return (
      <CarouselContext.Provider value={{ carouselRef, api: api as NonNullable<CarouselApi>, opts, orientation: orientation || "horizontal", scrollPrev, scrollNext, canScrollPrev, canScrollNext }}>
        <div ref={ref} {...props} className={cn("relative", className)}>
          <div ref={carouselRef} className="overflow-hidden">
            <div className={cn("flex", orientation === "horizontal" ? "-ml-4" : "-mt-4 flex-col")}>{children}</div>
          </div>
        </div>
      </CarouselContext.Provider>
    );
  }
);
Carousel.displayName = "Carousel";

const CarouselContent = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(({ className, ...props }, ref) => {
  const { carouselRef, orientation } = useCarousel();
  return (
    <div ref={carouselRef} className="overflow-hidden">
      <div ref={ref} className={cn("flex", orientation === "horizontal" ? "-ml-4" : "-mt-4 flex-col", className)} {...props} />
    </div>
  );
});
CarouselContent.displayName = "CarouselContent";

const CarouselItem = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(({ className, ...props }, ref) => {
  const { orientation } = useCarousel();
  return (
    <div ref={ref} role="group" aria-roledescription="slide"
      className={cn("min-w-0 shrink-0 grow-0 basis-full", orientation === "horizontal" ? "pl-4" : "pt-4", className)} {...props} />
  );
});
CarouselItem.displayName = "CarouselItem";

const CarouselPrevious = React.forwardRef<HTMLButtonElement, React.ComponentProps<typeof Button>>(
  ({ className, variant = "outline", size = "icon", ...props }, ref) => {
    const { scrollPrev, canScrollPrev } = useCarousel();
    return (
      <Button ref={ref} variant={variant} size={size} disabled={!canScrollPrev} onClick={scrollPrev}
        className={cn("h-8 w-8 rounded-full", className)} {...props}>
        <ArrowLeft className="h-4 w-4" /><span className="sr-only">Previous slide</span>
      </Button>
    );
  }
);
CarouselPrevious.displayName = "CarouselPrevious";

const CarouselNext = React.forwardRef<HTMLButtonElement, React.ComponentProps<typeof Button>>(
  ({ className, variant = "outline", size = "icon", ...props }, ref) => {
    const { scrollNext, canScrollNext } = useCarousel();
    return (
      <Button ref={ref} variant={variant} size={size} disabled={!canScrollNext} onClick={scrollNext}
        className={cn("h-8 w-8 rounded-full", className)} {...props}>
        <ArrowRight className="h-4 w-4" /><span className="sr-only">Next slide</span>
      </Button>
    );
  }
);
CarouselNext.displayName = "CarouselNext";

export { type CarouselApi, Carousel, CarouselContent, CarouselItem, CarouselPrevious, CarouselNext };

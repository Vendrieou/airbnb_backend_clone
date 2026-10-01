import { useState } from "react";
import { toast } from "sonner";
import {
  Accordion, AccordionContent, AccordionItem, AccordionTrigger,
} from "@/components/ui/accordion";
import {
  AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent,
  AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { AspectRatio } from "@/components/ui/aspect-ratio";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import {
  Breadcrumb, BreadcrumbEllipsis, BreadcrumbItem, BreadcrumbLink,
  BreadcrumbList, BreadcrumbPage, BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";
import { Button } from "@/components/ui/button";
import { Calendar } from "@/components/ui/calendar";
import {
  Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle,
} from "@/components/ui/card";
import { Checkbox } from "@/components/ui/checkbox";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import { Command, CommandGroup, CommandInput, CommandItem, CommandList } from "@/components/ui/command";
import {
  ContextMenu, ContextMenuContent, ContextMenuItem, ContextMenuLabel,
  ContextMenuSeparator, ContextMenuShortcut, ContextMenuTrigger,
} from "@/components/ui/context-menu";
import {
  Dialog, DialogClose, DialogContent, DialogDescription, DialogFooter,
  DialogHeader, DialogTitle, DialogTrigger,
} from "@/components/ui/dialog";
import {
  Drawer, DrawerClose, DrawerContent, DrawerDescription, DrawerFooter,
  DrawerHeader, DrawerTitle, DrawerTrigger,
} from "@/components/ui/drawer";
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel,
  DropdownMenuSeparator, DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { HoverCard, HoverCardContent, HoverCardTrigger } from "@/components/ui/hover-card";
import { InputOTP, InputOTPGroup, InputOTPSeparator, InputOTPSlot } from "@/components/ui/input-otp";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Menubar, MenubarContent, MenubarItem, MenubarMenu, MenubarSeparator,
  MenubarShortcut, MenubarTrigger,
} from "@/components/ui/menubar";
import {
  NavigationMenu, NavigationMenuContent, NavigationMenuItem, NavigationMenuLink,
  NavigationMenuList, NavigationMenuTrigger, navigationMenuTriggerStyle,
} from "@/components/ui/navigation-menu";
import {
  Pagination, PaginationContent, PaginationEllipsis, PaginationItem,
  PaginationLink, PaginationNext, PaginationPrevious,
} from "@/components/ui/pagination";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Progress } from "@/components/ui/progress";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { ResizableHandle, ResizablePanel, ResizablePanelGroup } from "@/components/ui/resizable";
import { ScrollArea } from "@/components/ui/scroll-area";
import {
  Select, SelectContent, SelectItem, SelectTrigger, SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { Slider } from "@/components/ui/slider";
import { Switch } from "@/components/ui/switch";
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from "@/components/ui/table";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { Toggle } from "@/components/ui/toggle";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-8">
      <h2 className="mb-3 text-lg font-semibold">{title}</h2>
      <div className="rounded-xl border border-border bg-card p-5">{children}</div>
    </section>
  );
}

export default function UiKitPage() {
  const [date, setDate] = useState<Date | undefined>(new Date());
  const [progress, setProgress] = useState(60);
  const [otp, setOtp] = useState("");

  return (
    <TooltipProvider>
      <div className="mx-auto max-w-5xl px-4 py-8">
        <h1 className="text-2xl font-bold">UI Kit — 46 komponen shadcn/Radix</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Semua komponen src/components/ui dipakai di halaman ini sebagai smoke-test visual.
        </p>

        <Section title="Button / Badge / Avatar">
          <div className="flex flex-wrap items-center gap-3">
            <Button>Default</Button>
            <Button variant="secondary">Secondary</Button>
            <Button variant="destructive">Destructive</Button>
            <Button variant="outline">Outline</Button>
            <Button variant="ghost">Ghost</Button>
            <Button variant="link">Link</Button>
            <Button size="sm">Small</Button>
            <Badge>New</Badge>
            <Badge variant="secondary">ok</Badge>
            <Avatar>
              <AvatarImage src="" alt="user" />
              <AvatarFallback>HK</AvatarFallback>
            </Avatar>
          </div>
        </Section>

        <Section title="Alert & Sonner toast">
          <Alert>
            <AlertTitle>Info</AlertTitle>
            <AlertDescription>Kamar 12 sudah checkout H+3 — task housekeeping dibuat otomatis.</AlertDescription>
          </Alert>
          <Alert variant="destructive" className="mt-3">
            <AlertTitle>Waspada</AlertTitle>
            <AlertDescription>Angsuran ke-2 melewati jatuh tempo.</AlertDescription>
          </Alert>
          <Button className="mt-3" onClick={() => toast.success("Pembayaran dicatat ✓")}>
            Kirim toast
          </Button>
        </Section>

        <Section title="Form controls">
          <div className="grid gap-5 sm:grid-cols-2">
            <div>
              <Label htmlFor="nama">Nama tamu</Label>
              <Input id="nama" placeholder="Budi Santoso" className="mt-1" />
            </div>
            <div>
              <Label htmlFor="cat">Catatan</Label>
              <Textarea id="cat" className="mt-1" placeholder="Permintaan khusus…" />
            </div>
            <div className="flex items-center gap-2">
              <Checkbox id="cicil" />
              <Label htmlFor="cicil">Bayar dicicil</Label>
            </div>
            <div className="flex items-center gap-2">
              <Switch id="wa" />
              <Label htmlFor="wa">Sinkron WhatsApp</Label>
            </div>
            <Select defaultValue="monthly">
              <SelectTrigger aria-label="Periode sewa"><SelectValue /></SelectTrigger>
              <SelectContent>
                <SelectItem value="daily">Harian</SelectItem>
                <SelectItem value="weekly">Mingguan</SelectItem>
                <SelectItem value="monthly">Bulanan</SelectItem>
              </SelectContent>
            </Select>
            <RadioGroup defaultValue="transfer">
              <div className="flex items-center gap-2">
                <RadioGroupItem value="transfer" id="r1" /><Label htmlFor="r1">Transfer</Label>
              </div>
              <div className="flex items-center gap-2">
                <RadioGroupItem value="qris" id="r2" /><Label htmlFor="r2">QRIS</Label>
              </div>
            </RadioGroup>
            <Slider defaultValue={[50]} max={100} step={1} onValueChange={(v) => setProgress(v[0])} />
            <Progress value={progress} />
            <ToggleGroup type="single" defaultValue="grid">
              <ToggleGroupItem value="grid">Grid</ToggleGroupItem>
              <ToggleGroupItem value="list">List</ToggleGroupItem>
            </ToggleGroup>
            <Toggle aria-label="Favorit">★</Toggle>
            <div>
              <Label htmlFor="otp">Kode OTP passcode smartlock</Label>
              <InputOTP id="otp" maxLength={6} value={otp} onChange={setOtp} className="mt-1">
                <InputOTPGroup>
                  <InputOTPSlot index={0} /><InputOTPSlot index={1} /><InputOTPSlot index={2} />
                </InputOTPGroup>
                <InputOTPSeparator />
                <InputOTPGroup>
                  <InputOTPSlot index={3} /><InputOTPSlot index={4} /><InputOTPSlot index={5} />
                </InputOTPGroup>
              </InputOTP>
            </div>
            <Calendar mode="single" selected={date} onSelect={setDate} className="rounded-md border" />
          </div>
        </Section>

        <Section title="Overlays: Dialog / AlertDialog / Drawer / Popover / Tooltip / Hover / Context / Dropdown">
          <div className="flex flex-wrap gap-3">
            <Dialog>
              <DialogTrigger asChild><Button variant="outline">Dialog</Button></DialogTrigger>
              <DialogContent>
                <DialogHeader>
                  <DialogTitle>Detail unit 12A</DialogTitle>
                  <DialogDescription>Setup seven key / TTLOCK smart lock.</DialogDescription>
                </DialogHeader>
                <Input placeholder="Master key name" />
                <DialogFooter>
                  <DialogClose asChild><Button variant="ghost">Batal</Button></DialogClose>
                  <Button>Simpan</Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
            <AlertDialog>
              <AlertDialogTrigger asChild><Button variant="outline">Alert Dialog</Button></AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Batalkan booking?</AlertDialogTitle>
                  <AlertDialogDescription>Tindakan ini tidak dapat dibatalkan.</AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Kembali</AlertDialogCancel>
                  <AlertDialogAction>Ya, batalkan</AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
            <Drawer>
              <DrawerTrigger asChild><Button variant="outline">Drawer</Button></DrawerTrigger>
              <DrawerContent>
                <DrawerHeader>
                  <DrawerTitle>Generate temporary key</DrawerTitle>
                  <DrawerDescription>Passcode aktif selama durasi stay.</DrawerDescription>
                </DrawerHeader>
                <DrawerFooter>
                  <DrawerClose asChild><Button variant="outline">Tutup</Button></DrawerClose>
                </DrawerFooter>
              </DrawerContent>
            </Drawer>
            <Popover>
              <PopoverTrigger asChild><Button variant="outline">Popover</Button></PopoverTrigger>
              <PopoverContent className="w-72 text-sm">Jadwal cicilan: DP 20% + 3 angsuran.</PopoverContent>
            </Popover>
            <Tooltip>
              <TooltipTrigger asChild><Button variant="outline">Tooltip</Button></TooltipTrigger>
              <TooltipContent>Status centang WhatsApp</TooltipContent>
            </Tooltip>
            <HoverCard>
              <HoverCardTrigger asChild><Button variant="link">@housekeeper_01</Button></HoverCardTrigger>
              <HoverCardContent className="w-64 text-sm">Siti — 128 task selesai, rating 4.9.</HoverCardContent>
            </HoverCard>
            <ContextMenu>
              <ContextMenuTrigger className="rounded-md border border-dashed px-4 py-2 text-sm">
                Klik kanan saya
              </ContextMenuTrigger>
              <ContextMenuContent className="w-48">
                <ContextMenuLabel>Unit 12A</ContextMenuLabel>
                <ContextMenuItem>Pindahkan <ContextMenuShortcut>⌘M</ContextMenuShortcut></ContextMenuItem>
                <ContextMenuSeparator />
                <ContextMenuItem className="text-bad focus:text-bad">Hapus</ContextMenuItem>
              </ContextMenuContent>
            </ContextMenu>
            <DropdownMenu>
              <DropdownMenuTrigger asChild><Button variant="outline">Dropdown</Button></DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-44">
                <DropdownMenuLabel>Akun</DropdownMenuLabel>
                <DropdownMenuItem>Profil</DropdownMenuItem>
                <DropdownMenuSeparator />
                <DropdownMenuItem>Keluar</DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        </Section>

        <Section title="Menubar / NavigationMenu / Command">
          <Menubar>
            <MenubarMenu>
              <MenubarTrigger>Berkas</MenubarTrigger>
              <MenubarContent>
                <MenubarItem>Booking baru <MenubarShortcut>⌘N</MenubarShortcut></MenubarItem>
                <MenubarSeparator />
                <MenubarItem>Tutup</MenubarItem>
              </MenubarContent>
            </MenubarMenu>
            <MenubarMenu>
              <MenubarTrigger>Tampilan</MenubarTrigger>
              <MenubarContent><MenubarItem>Grid lantai</MenubarItem></MenubarContent>
            </MenubarMenu>
          </Menubar>
          <NavigationMenu className="mt-3">
            <NavigationMenuList>
              <NavigationMenuItem>
                <NavigationMenuTrigger>Master data</NavigationMenuTrigger>
                <NavigationMenuContent>
                  <ul className="grid w-80 gap-2 p-2">
                    <li><NavigationMenuLink asChild><a className={navigationMenuTriggerStyle()} href="#floors">Floor</a></NavigationMenuLink></li>
                    <li><NavigationMenuLink asChild><a className={navigationMenuTriggerStyle()} href="#units">Unit kamar</a></NavigationMenuLink></li>
                  </ul>
                </NavigationMenuContent>
              </NavigationMenuItem>
              <NavigationMenuItem>
                <NavigationMenuLink asChild><a className={navigationMenuTriggerStyle()} href="#reservasi">Reservasi</a></NavigationMenuLink>
              </NavigationMenuItem>
            </NavigationMenuList>
          </NavigationMenu>
          <Command className="mt-3 max-w-md rounded-lg border">
            <CommandInput placeholder="Cari unit / floor…" />
            <CommandList>
              <CommandGroup heading="Floors">
                <CommandItem>Floor 1</CommandItem>
                <CommandItem>Floor 2</CommandItem>
              </CommandGroup>
            </CommandList>
          </Command>
        </Section>

        <Section title="Tabs / Accordion / Collapsible">
          <Tabs defaultValue="harian">
            <TabsList>
              <TabsTrigger value="harian">Harian</TabsTrigger>
              <TabsTrigger value="mingguan">Mingguan</TabsTrigger>
              <TabsTrigger value="bulanan">Bulanan</TabsTrigger>
            </TabsList>
            <TabsContent value="harian" className="text-sm">Rp 250.000 / malam</TabsContent>
            <TabsContent value="mingguan" className="text-sm">Rp 1.500.000 / minggu</TabsContent>
            <TabsContent value="bulanan" className="text-sm">Rp 5.000.000 / bulan · bisa dicicil</TabsContent>
          </Tabs>
          <Accordion type="single" collapsible className="mt-4">
            <AccordionItem value="a">
              <AccordionTrigger>Kebijakan cicilan</AccordionTrigger>
              <AccordionContent>DP 20%, sisa dipecah rata ke 3 angsuran.</AccordionContent>
            </AccordionItem>
          </Accordion>
          <Collapsible>
            <CollapsibleTrigger asChild><Button variant="ghost" className="mt-2">Tampilkan jadwal</Button></CollapsibleTrigger>
            <CollapsibleContent className="mt-2 text-sm text-muted-foreground">
              Angsuran 1: 5 Okt · Angsuran 2: 5 Nov · Angsuran 3: 5 Des
            </CollapsibleContent>
          </Collapsible>
        </Section>

        <Section title="Table / Card / Breadcrumb / Pagination">
          <Breadcrumb>
            <BreadcrumbList>
              <BreadcrumbItem><BreadcrumbLink href="/">Home</BreadcrumbLink></BreadcrumbItem>
              <BreadcrumbSeparator />
              <BreadcrumbItem><BreadcrumbEllipsis /></BreadcrumbItem>
              <BreadcrumbSeparator />
              <BreadcrumbItem><BreadcrumbPage>Floor 2 · Unit 12A</BreadcrumbPage></BreadcrumbItem>
            </BreadcrumbList>
          </Breadcrumb>
          <Card className="mt-3">
            <CardHeader>
              <CardTitle>Villa Bulanan</CardTitle>
              <CardDescription>Sewa 30 malam, cicilan aktif</CardDescription>
            </CardHeader>
            <CardContent>
              <Table>
                <TableHeader>
                  <TableRow><TableHead>Angsuran</TableHead><TableHead>Jatuh tempo</TableHead><TableHead>Status</TableHead></TableRow>
                </TableHeader>
                <TableBody>
                  <TableRow><TableCell>#1 — Rp 8.000.000</TableCell><TableCell>05/10/2026</TableCell><TableCell><Badge>Lunas</Badge></TableCell></TableRow>
                  <TableRow><TableCell>#2 — Rp 8.000.000</TableCell><TableCell>05/11/2026</TableCell><TableCell><Badge variant="secondary">Pending</Badge></TableCell></TableRow>
                </TableBody>
              </Table>
            </CardContent>
            <CardFooter>
              <Pagination className="mx-0 justify-start">
                <PaginationContent>
                  <PaginationItem><PaginationPrevious href="#" /></PaginationItem>
                  <PaginationItem><PaginationLink href="#" isActive>1</PaginationLink></PaginationItem>
                  <PaginationItem><PaginationLink href="#">2</PaginationLink></PaginationItem>
                  <PaginationItem><PaginationEllipsis /></PaginationItem>
                  <PaginationItem><PaginationNext href="#" /></PaginationItem>
                </PaginationContent>
              </Pagination>
            </CardFooter>
          </Card>
        </Section>

        <Section title="Resizable / ScrollArea / AspectRatio / Skeleton / Separator / Progress">
          <ResizablePanelGroup orientation="horizontal" className="min-h-40 rounded-lg border">
            <ResizablePanel defaultSize={40}>
              <ScrollArea className="h-36 p-3 text-sm">
                {Array.from({ length: 20 }, (_, i) => <p key={i} className="py-1">Riwayat aktivitas #{i + 1}</p>)}
              </ScrollArea>
            </ResizablePanel>
            <ResizableHandle withHandle />
            <ResizablePanel defaultSize={60} className="p-3">
              <AspectRatio ratio={16 / 9}>
                <div className="flex h-full w-full items-center justify-center rounded-md bg-muted text-sm text-muted-foreground">
                  Foto bukti cleaning (upload ≥1 image sebelum review)
                </div>
              </AspectRatio>
              <Skeleton className="mt-3 h-4 w-2/3" />
              <Skeleton className="mt-2 h-4 w-1/3" />
            </ResizablePanel>
          </ResizablePanelGroup>
          <Separator className="my-4" />
          <Progress value={80} />
        </Section>

        <Section title="Chart (recharts)">
          <Card>
            <CardContent className="pt-6">
              {/* chart.tsx wrapper tersedia; contoh sederhana */}
              <p className="text-sm text-muted-foreground">
                Komponen <code>chart.tsx</code> (ChartContainer/Tooltip/Legend) siap dipakai untuk grafik omset per outlet.
              </p>
            </CardContent>
          </Card>
        </Section>
      </div>
    </TooltipProvider>
  );
}

import { useEffect, useMemo, useState } from "react";
import { Button } from "../components/Button";
import { Badge } from "../components/Badge";
import { Input } from "../components/Input";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "../components/Tabs";
import styles from "./_index.module.css";

const screens = [
  ["dashboard","Dashboard"],["market","Market"],["commodity","Commodity"],["signals","Signals"],
  ["oi","OI Lab"],["watchlist","Watchlist"],["search","Search"],["charts","Charts"],
  ["chain","Option Chain"],["news","News"],["details","Market Details"],["angel","Angel API"],
  ["nse","NSE"],["mcp","NSE MCP"],["data","Data"],["instruments","Instruments"],
  ["settings","Settings"],["more","More"],
] as const;

const indices=["NIFTY 50","BANKNIFTY","FINNIFTY","MIDCPNIFTY","SENSEX","NIFTYNXT50","BANKEX","INDIA VIX"];
const commodities=["GOLD","SILVER","CRUDE OIL","NATURAL GAS","COPPER","ALUMINIUM","ZINC","LEAD"];
const timeframes=["1m","2m","3m","5m","10m","15m","30m","1h","2h","4h","1D"];

export default function Index(){
  const [tab,setTab]=useState<(typeof screens)[number][0]>("dashboard");
  const [clock,setClock]=useState("");
  const [theme,setTheme]=useState<"dark"|"light">("dark");
  const [clientId,setClientId]=useState(""); const [mpin,setMpin]=useState(""); const [totp,setTotp]=useState("");
  const [status,setStatus]=useState("NOT CONNECTED"); const [busy,setBusy]=useState(false);
  const [message,setMessage]=useState("Enter Client ID, MPIN and current TOTP to connect.");
  const [search,setSearch]=useState("");
  useEffect(()=>{const tick=()=>setClock(new Intl.DateTimeFormat("en-IN",{hour:"2-digit",minute:"2-digit",second:"2-digit",hour12:false,timeZone:"Asia/Kolkata"}).format(new Date()));tick();const t=window.setInterval(tick,1000);return()=>clearInterval(t)},[]);
  useEffect(()=>{
    const saved=window.localStorage.getItem("algodesk-theme");
    if(saved==="light"||saved==="dark") setTheme(saved);
  },[]);
  useEffect(()=>{
    document.documentElement.classList.toggle("dark",theme==="dark");
    document.documentElement.classList.toggle("light",theme==="light");
    document.documentElement.dataset.theme=theme;
    window.localStorage.setItem("algodesk-theme",theme);
  },[theme]);
  async function login(){
    if(!clientId||!mpin||!/^[0-9]{6}$/.test(totp)){setMessage("Client ID, 4-digit MPIN and current 6-digit TOTP are required.");return}
    setBusy(true);setMessage("Connecting to Angel One SmartAPI…");
    try{const r=await fetch("/_api/angel/login",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({clientId,mpin,totp})});const d=await r.json();setStatus(d.connected?"CONNECTED":"NOT CONNECTED");setMessage(d.message||"Connection response received.")}
    catch{setStatus("NOT CONNECTED");setMessage("Backend connection is not available.")}finally{setBusy(false)}
  }
  const filtered=useMemo(()=>[...indices,...commodities].filter(x=>x.toLowerCase().includes(search.toLowerCase())),[search]);
  return <main className={styles.shell}>
    <header className={styles.header}>
      <div className={styles.brand}><span className={styles.brandMark}>A</span><div><div className={styles.kicker}>NSE ALGO SIGNAL</div><h1>Smart Market Terminal</h1><p>Angel One SmartAPI · NSE MCP · Real Data · No Algo/Strategy</p></div></div>
      <div className={styles.headerRight}><Badge variant={status==="CONNECTED"?"success":"outline"}>{status}</Badge><span className={styles.clock}>IST {clock}</span><Button size="sm" variant="outline" onClick={()=>setTheme(theme==="dark"?"light":"dark")}>{theme==="dark"?"☀ Light":"☾ Dark"}</Button></div>
    </header>
    <Tabs value={tab} onValueChange={v=>setTab(v as typeof tab)}>
      <TabsList className={styles.tabs}>{screens.map(([id,label],i)=><TabsTrigger key={id} value={id}>{String(i+1).padStart(2,"0")} · {label}</TabsTrigger>)}</TabsList>
      <TabsContent value="dashboard"><Page title="Dashboard" subtitle="18-screen command center"><div className={styles.metrics}>{[["ANGEL API",status,"Broker connection"],["DATA SOURCE","ANGEL ONE","Verified payload only"],["NSE MCP","—","Not connected"],["SESSION","—","After login"]].map(x=><Metric key={x[0]} label={x[0]} value={x[1]} note={x[2]}/>)}</div><div className={styles.grid}><Panel title="MARKET SNAPSHOT"><Empty title="NIFTY — · ATM —" text="Verified values appear only after a successful API session and live market payload."/></Panel><Panel title="CONNECTION CENTER"><Connection name="Angel One SmartAPI" value={status}/><Connection name="NSE server" value="NOT CONFIGURED"/><Connection name="NSE MCP" value="NOT CONNECTED"/></Panel></div></Page></TabsContent>
      <TabsContent value="market"><Page title="Market" subtitle="Indian indices · breadth · gainers/losers"><IndexGrid items={indices}/><div className={styles.grid}><Panel title="MARKET BREADTH"><Empty title="—" text="Gainers, losers and breadth will appear only from verified live data."/></Panel><Panel title="LIVE STATUS"><Empty title="No demo data" text="No fabricated prices or ticks are bundled."/></Panel></div></Page></TabsContent>
      <TabsContent value="commodity"><Page title="Commodity" subtitle="MCX instruments · live API only"><IndexGrid items={commodities}/><Panel title="COMMODITY DATA"><Empty title="Waiting for verified payload" text="Gold, Silver, Crude Oil, Natural Gas and available MCX instruments use the connected API source."/></Panel></Page></TabsContent>
      <TabsContent value="signals"><Page title="Signals" subtitle="Reserved for the next phase"><Panel title="ALGO / STRATEGY ENGINE"><Empty title="INTENTIONALLY DISABLED" text="No entry, exit, SL, target or Buy/Sell strategy is calculated in this phase. The original signal screen is retained without an active strategy engine."/></Panel></Page></TabsContent>
      <TabsContent value="oi"><Page title="OI Lab" subtitle="CE/PE · strike · OI · OI change · PCR"><div className={styles.chips}>{["NIFTY","BANKNIFTY","FINNIFTY","SENSEX","CE","PE","ATM","ITM","OTM"].map(x=><Button key={x} size="sm" variant="outline">{x}</Button>)}</div><Panel title="OPTION OI WORKSPACE"><Empty title="OI n/a" text="OI, OI change, price change, PCR and buildup classification will render only when the source provides the required fields."/></Panel></Page></TabsContent>
      <TabsContent value="watchlist"><Page title="Watchlist" subtitle="Live LTP · change · OI badge"><IndexGrid items={["NIFTY 50","BANKNIFTY","SENSEX","RELIANCE","SBIN","ITC","ICICIBANK","HDFCBANK"]}/></Page></TabsContent>
      <TabsContent value="search"><Page title="Search" subtitle="Instrument search + AI-ready research"><Input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search index, commodity or instrument"/><div className={styles.list}>{filtered.length?filtered.map(x=><Row key={x} name={x} meta="Verified API data only"/>):<Empty title="No matching instrument" text="Search uses the instrument universe once loaded from the API."/>}</div><Panel title="AI ASSIST"><Empty title="AI research ready" text="AI can explain supplied market/news content. It will not invent news or create Buy/Sell recommendations in this phase."/></Panel></Page></TabsContent>
      <TabsContent value="charts"><Page title="Charts" subtitle="Live market chart workspace"><div className={styles.chips}>{timeframes.map(x=><Button key={x} size="sm" variant={x==="5m"?"primary":"outline"}>{x}</Button>)}</div><Panel title="PRICE CHART"><div className={styles.chartBlank}><strong>LIVE CHART AWAITS DATA</strong><span>8 EMA / 13 EMA configuration is retained for later analytics; no strategy calculation is active now.</span></div></Panel></Page></TabsContent>
      <TabsContent value="chain"><Page title="Option Chain" subtitle="CE/PE · strike · LTP · OI · OI change · ATM/ITM/OTM"><div className={styles.chips}>{["NIFTY","BANKNIFTY","FINNIFTY","SENSEX","ATM","ITM","OTM"].map(x=><Button key={x} size="sm" variant="outline">{x}</Button>)}</div><Panel title="LIVE OPTION CHAIN"><Empty title="Waiting for verified option-chain payload" text="No fabricated strikes, premiums, OI or PCR values are shown."/></Panel></Page></TabsContent>
      <TabsContent value="news"><Page title="News" subtitle="Verified market/news sources · no fake headlines"><div className={styles.newsGrid}><NewsCard title="Latest Market News" text="Connect a permitted news/RSS provider to populate live headlines."/><NewsCard title="Indian Market" text="NIFTY, BANKNIFTY and company news will be grouped here."/><NewsCard title="Commodity" text="Gold, Silver, Crude Oil and other commodity news."/><NewsCard title="Economy / Global" text="Macro and global market updates from the configured source."/></div><Panel title="NEWS PIPELINE"><Empty title="SOURCE NOT CONFIGURED" text="Architecture is ready for a server-side news provider. Each item will show source and timestamp; AI summaries will use only supplied article content."/></Panel></Page></TabsContent>
      <TabsContent value="details"><Page title="Market Details" subtitle="Breadth · FII/DII · overview · market context"><div className={styles.threeGrid}><DataCard title="FII / DII" body="Awaiting verified data"/><DataCard title="Breadth" body="Awaiting verified data"/><DataCard title="Market Overview" body="Awaiting verified data"/></div><Panel title="NEWS & EVENTS"><Empty title="Linked market context" text="News and event details will be shown when a verified source is connected."/></Panel></Page></TabsContent>
      <TabsContent value="angel"><Page title="Angel API" subtitle="Secure SmartAPI connection"><div className={styles.twoCol}><Panel title="BROKER CONNECTION"><div className={styles.form}><label>CLIENT ID</label><Input value={clientId} onChange={e=>setClientId(e.target.value)} placeholder="Enter Angel One Client ID"/><label>MPIN</label><Input value={mpin} onChange={e=>setMpin(e.target.value.replace(/\D/g,"").slice(0,4))} placeholder="Enter 4-digit MPIN" type="password" inputMode="numeric"/><label>CURRENT TOTP</label><Input value={totp} onChange={e=>setTotp(e.target.value.replace(/\D/g,"").slice(0,6))} placeholder="Enter current 6-digit TOTP" inputMode="numeric"/><div className={styles.secretStatus}><span>SmartAPI application credential is already secured on the backend.</span><Badge variant="outline">SERVER SIDE</Badge></div><Button onClick={login} disabled={busy}>{busy?"CONNECTING…":"SECURE LOGIN"}</Button><p className={styles.formMessage}>{message}</p></div></Panel><Panel title="ANGEL ONE FLOW"><Step n="01" text="Enter the SmartAPI API key in the masked field above."/><Step n="02" text="Client ID, MPIN and current TOTP are entered for authentication."/><Step n="03" text="The backend receives the login payload and connects to SmartAPI when configured."/><Step n="04" text="Market data is displayed read-only. No orders are placed."/></Panel></div></Page></TabsContent>
      <TabsContent value="nse"><Page title="NSE" subtitle="Server reachability and real-time feed are separate"><Panel title="NSE CONNECTION"><div className={styles.statusBig}>NOT CONFIGURED</div><p className={styles.empty}>HTTP reachability does not imply a live market feed. A verified feed status will be shown separately.</p></Panel></Page></TabsContent>
      <TabsContent value="mcp"><Page title="NSE MCP" subtitle="Official MCP connection workspace"><Panel title="NSE MCP"><div className={styles.apiLine}>https://mcp.nseindia.in/cmmkt/mcp</div><Empty title="NOT CONNECTED" text="Tools, arguments, refresh, calls and responses appear only when the endpoint is reachable."/></Panel></Page></TabsContent>
      <TabsContent value="data"><Page title="Data" subtitle="Live data center · CSV/PDF/Excel/image intake"><div className={styles.threeGrid}><DataCard title="Market Data" body="Live API payload only"/><DataCard title="Option Chain" body="CE / PE · OI · PCR · strike"/><DataCard title="File Intake" body="CSV · PDF · Excel · image"/></div><Panel title="DATA STATUS"><Empty title="No demo market data bundled" text="Uploaded files can feed analysis only after validation; live API data remains separate."/></Panel></Page></TabsContent>
      <TabsContent value="instruments"><Page title="Instruments" subtitle="Searchable scrip/instrument universe"><Input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search instrument"/><div className={styles.list}>{filtered.map(x=><Row key={x} name={x} meta="Instrument master / API"/>)}</div></Page></TabsContent>
      <TabsContent value="settings"><Page title="Settings" subtitle="App configuration without strategy execution"><div className={styles.threeGrid}><DataCard title="Theme" body="Dark / Light"/><DataCard title="Timeframes" body={timeframes.join(" · ")}/><DataCard title="Indicators" body="8 EMA · 13 EMA"/></div><Panel title="ANALYTICS PHASE"><Empty title="Strategy disabled" text="Configuration is retained for the future analytics engine; no trade signal is calculated now."/></Panel></Page></TabsContent>
      <TabsContent value="more"><Page title="More" subtitle="Additional tools retained from the original app"><div className={styles.threeGrid}><DataCard title="Portfolio" body="Read-only positions / orders area retained"/><DataCard title="AI" body="Research assistant / explain supplied content"/><DataCard title="Disclaimer" body="Read-only · no order placement"/></div><div className={styles.quickGrid}>{[["Angel API","angel"],["Option Chain","chain"],["Charts","charts"],["NSE","nse"],["NSE MCP","mcp"],["Data","data"]].map(([label,id])=><Button key={id} variant="outline" onClick={()=>setTab(id as typeof tab)}>{label}</Button>)}</div></Page></TabsContent>
    </Tabs>
    <footer>18 tabs · 18 screens · Real API data only · No fake/demo market values · No order placement · Algo/strategy engine deferred.</footer>
  </main>
}

function Page({title,subtitle,children}:{title:string;subtitle:string;children:React.ReactNode}){return <div className={styles.page}><div className={styles.pageTitle}><div><div className={styles.kicker}>SCREEN</div><h2>{title}</h2><p>{subtitle}</p></div><Badge variant="outline">LIVE DATA ONLY</Badge></div>{children}</div>}
function Panel({title,children}:{title:string;children:React.ReactNode}){return <section className={styles.panel}><div className={styles.panelHead}><span>{title}</span><span className={styles.mono}>API</span></div>{children}</section>}
function Empty({title,text}:{title:string;text:string}){return <div className={styles.emptyBox}><strong>{title}</strong><span>{text}</span></div>}
function Metric({label,value,note}:{label:string;value:string;note:string}){return <div className={styles.metric}><span>{label}</span><strong>{value}</strong><small>{note}</small></div>}
function DataCard({title,body}:{title:string;body:string}){return <div className={styles.dataCard}><span>{title}</span><strong>{body}</strong></div>}
function IndexGrid({items}:{items:string[]}){return <div className={styles.indexGrid}>{items.map(x=><div className={styles.indexCard} key={x}><span>{x}</span><strong>—</strong><small>API LTP · Change</small></div>)}</div>}
function Row({name,meta}:{name:string;meta:string}){return <div className={styles.row}><b>{name}</b><span>{meta}</span><strong>—</strong></div>}
function Connection({name,value}:{name:string;value:string}){return <div className={styles.connectionRow}><span>{name}</span><Badge variant={value==="CONNECTED"?"success":"outline"}>{value}</Badge></div>}
function Step({n,text}:{n:string;text:string}){return <div className={styles.step}><b>{n}</b><span>{text}</span></div>}
function NewsCard({title,text}:{title:string;text:string}){return <div className={styles.newsCard}><Badge variant="outline">NEWS</Badge><h3>{title}</h3><p>{text}</p><span>Source / time shown when configured</span></div>}

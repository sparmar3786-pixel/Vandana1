import { useEffect, useRef, useState } from "react";
import {
  createChart, CrosshairMode, IChartApi, ISeriesApi, IPriceLine, UTCTimestamp
} from "lightweight-charts";

type Bar = { t:number; o:number; h:number; l:number; c:number; v:number };
const STEP = { "1m":60, "5m":300, "15m":900, "1h":3600, "1D":86400 } as const;
type TF = keyof typeof STEP;
const IST = 19800;
const T = (t:number) => (t + IST) as UTCTimestamp;

const ema=(b:Bar[],n:number)=>{
  const k=2/(n+1); let e=b[0]?.c ?? 0;
  return b.map(x=>({time:T(x.t),value:(e=x.c*k+e*(1-k))}));
};
const vwap=(b:Bar[])=>{
  let pv=0,vv=0,day=-1;
  return b.map(x=>{
    const d=Math.floor((x.t+IST)/86400);
    if(d!==day){day=d;pv=0;vv=0;}
    const v=x.v||1; pv+=((x.h+x.l+x.c)/3)*v; vv+=v;
    return {time:T(x.t),value:pv/vv};
  });
};

export default function CandleChart({base,index,dark=true}:{base:string;index:string;dark?:boolean}){
  const box=useRef<HTMLDivElement>(null);
  const chart=useRef<IChartApi>();
  const S=useRef<{c:ISeriesApi<"Candlestick">;v:ISeriesApi<"Histogram">;e1:ISeriesApi<"Line">;e2:ISeriesApi<"Line">;vw:ISeriesApi<"Line">}>();
  const bars=useRef<Bar[]>([]);
  const lines=useRef<IPriceLine[]>([]);
  const auto=useRef<IPriceLine[]>([]);
  const tool=useRef(false);
  const [tf,setTf]=useState<TF>("5m");
  const [drawing,setDrawing]=useState(false);
  const [show,setShow]=useState({ema:true,vwap:true});
  const [legend,setLegend]=useState("");

  useEffect(()=>{
    const ch=createChart(box.current!,{
      autoSize:true,crosshair:{mode:CrosshairMode.Normal},
      timeScale:{timeVisible:true,secondsVisible:false,rightOffset:6},
      rightPriceScale:{borderVisible:false},
      layout:{background:{color:"transparent"},textColor:"#9aa0a6"},
      grid:{vertLines:{color:"rgba(128,128,128,.08)"},horzLines:{color:"rgba(128,128,128,.08)"}}
    });
    const c=ch.addCandlestickSeries({upColor:"#26a69a",downColor:"#ef5350",borderVisible:false,wickUpColor:"#26a69a",wickDownColor:"#ef5350"});
    const v=ch.addHistogramSeries({priceFormat:{type:"volume"},priceScaleId:""});
    v.priceScale().applyOptions({scaleMargins:{top:0.82,bottom:0}});
    const mk=(color:string)=>ch.addLineSeries({color,lineWidth:1,priceLineVisible:false,lastValueVisible:false});
    S.current={c,v,e1:mk("#fbc02d"),e2:mk("#42a5f5"),vw:mk("#ab47bc")};
    chart.current=ch;
    ch.subscribeCrosshairMove(p=>{
      const d:any=p.seriesData.get(c);
      if(d)setLegend(`O ${d.open}  H ${d.high}  L ${d.low}  C ${d.close}`);
    });
    ch.subscribeClick(p=>{
      if(!tool.current||!p.point)return;
      const price=c.coordinateToPrice(p.point.y);
      if(price!=null)lines.current.push(c.createPriceLine({price,color:"#ff9800",lineWidth:1,lineStyle:2,axisLabelVisible:true,title:""}));
    });
    return()=>ch.remove();
  },[]);

  useEffect(()=>{tool.current=drawing;},[drawing]);
  useEffect(()=>{chart.current?.applyOptions({layout:{textColor:dark?"#9aa0a6":"#3c4043"}});},[dark]);
  useEffect(()=>{
    const s=S.current!; s.e1.applyOptions({visible:show.ema}); s.e2.applyOptions({visible:show.ema});
    s.vw.applyOptions({visible:show.vwap&&tf!=="1D"});
  },[show,tf]);

  useEffect(()=>{
    const ac=new AbortController();
    (async()=>{
      try{
        const r=await fetch(`${base}/api/candles?index=${index}&tf=${tf}`,{signal:ac.signal});
        if(!r.ok)return;
        const b:Bar[]=await r.json(); bars.current=b;
        const s=S.current!;
        s.c.setData(b.map(x=>({time:T(x.t),open:x.o,high:x.h,low:x.l,close:x.c})));
        s.v.setData(b.map(x=>({time:T(x.t),value:x.v,color:x.c>=x.o?"rgba(38,166,154,.4)":"rgba(239,83,80,.4)"})));
        s.e1.setData(ema(b,20)); s.e2.setData(ema(b,50)); s.vw.setData(tf==="1D"?[]:vwap(b));
        chart.current!.timeScale().fitContent();
        auto.current.forEach(l=>s.c.removePriceLine(l)); auto.current=[];
        if(tf!=="1D"&&b.length){
          const day=(t:number)=>Math.floor((t+IST)/86400);
          const today=day(b[b.length-1].t);
          const prev=b.filter(x=>day(x.t)<today);
          if(prev.length){
            const pd=prev.filter(x=>day(x.t)===day(prev[prev.length-1].t));
            const hi=Math.max(...pd.map(x=>x.h)),lo=Math.min(...pd.map(x=>x.l));
            auto.current.push(s.c.createPriceLine({price:hi,color:"#26a69a",lineWidth:1,lineStyle:1,title:"PDH"}));
            auto.current.push(s.c.createPriceLine({price:lo,color:"#ef5350",lineWidth:1,lineStyle:1,title:"PDL"}));
          }
        }
      }catch{}
    })();
    return()=>ac.abort();
  },[base,index,tf]);

  useEffect(()=>{
    let busy=false;
    const id=setInterval(async()=>{
      if(busy||!bars.current.length)return; busy=true;
      try{
        const r=await fetch(`${base}/api/spot/${index}`);
        if(!r.ok)return;
        const {spot,age_s}=await r.json(); if(age_s>30)return;
        const step=STEP[tf],off=tf==="1h"?33300:0,now=Math.floor(Date.now()/1000);
        const bucket=Math.floor((now+IST-off)/step)*step+off-IST;
        const b=bars.current,last=b[b.length-1];
        if(last.t===bucket){last.h=Math.max(last.h,spot);last.l=Math.min(last.l,spot);last.c=spot;}
        else if(bucket>last.t)b.push({t:bucket,o:spot,h:spot,l:spot,c:spot,v:0});
        else return;
        const x=b[b.length-1],s=S.current!;
        s.c.update({time:T(x.t),open:x.o,high:x.h,low:x.l,close:x.c});
        s.e1.update(ema(b,20).at(-1)!); s.e2.update(ema(b,50).at(-1)!);
        if(tf!=="1D")s.vw.update(vwap(b).at(-1)!);
      }catch{}finally{busy=false;}
    },2000);
    return()=>clearInterval(id);
  },[base,index,tf]);

  const clearLines=()=>{lines.current.forEach(l=>S.current!.c.removePriceLine(l));lines.current=[];};
  const btn=(on:boolean):React.CSSProperties=>({padding:"4px 10px",borderRadius:14,border:"1px solid #888",fontSize:12,background:on?"#6750a4":"transparent",color:on?"#fff":"inherit"});

  return <div style={{height:"100%",display:"flex",flexDirection:"column"}}>
    <div style={{display:"flex",gap:6,padding:6,overflowX:"auto"}}>
      {(Object.keys(STEP) as TF[]).map(k=><button key={k} style={btn(tf===k)} onClick={()=>setTf(k)}>{k}</button>)}
      <button style={btn(show.ema)} onClick={()=>setShow({...show,ema:!show.ema})}>EMA</button>
      <button style={btn(show.vwap)} onClick={()=>setShow({...show,vwap:!show.vwap})}>VWAP</button>
      <button style={btn(drawing)} onClick={()=>setDrawing(!drawing)}>Line ✏️</button>
      <button style={btn(false)} onClick={clearLines}>Clear</button>
    </div>
    <div style={{fontSize:11,padding:"0 8px",opacity:.8}}>{index} {tf} · {legend}</div>
    <div ref={box} style={{flex:1,minHeight:0}}/>
  </div>;
}

export type Json = JsonValue;
export type JsonArray = JsonValue[];
export type JsonObject = {[x:string]: JsonValue|undefined};
export type JsonPrimitive = boolean|number|string|null;
export type JsonValue = JsonArray|JsonObject|JsonPrimitive;
export interface AiMemory { category:string; createdAt:Date; evidence:Json|null; id:string; memoryDate:Date; outcome:string|null; summary:string; symbol:string|null; }
export interface MarketSnapshots { createdAt:Date; exchange:string; id:string; payload:Json; symbol:string; }
export interface TradeJournal { aiReasoning:string|null; createdAt:Date; entryPrice:string|null; exitPrice:string|null; id:string; outcome:string; setup:string; side:string; sourceSnapshot:Json|null; stopLoss:string|null; strikePrice:string|null; symbol:string; target:string|null; tradeDate:Date; userComment:string|null; }
export interface DB { aiMemory:AiMemory; marketSnapshots:MarketSnapshots; tradeJournal:TradeJournal; }
export const kyselyIdentifierOverrides:Record<string,string> = {};
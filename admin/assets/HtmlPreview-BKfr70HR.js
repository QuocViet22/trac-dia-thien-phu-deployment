import{t as e,v as t,y as n}from"./index-C7f-3h1b.js";function r(e){return e instanceof Error&&`status`in e&&e.status===404}function i(e){return e instanceof Error&&`status`in e&&e.status===409?{field:`seoAlias`,message:e.message}:{message:e instanceof Error?e.message:`Request failed`}}var a=n(t(),1),o=1e5,s=1048576,c=e=>`That file is too long${e?` (${e} characters)`:``}. HTML can be up to ${o} characters.`,l=class extends Error{constructor(e){super(e),this.name=`HtmlFileError`}};async function u(e){if(!(/\.html?$/i.test(e.name)||e.type===`text/html`))throw new l(`That file isn't HTML. Choose a .html or .htm file.`);if(e.size>s)throw new l(c());let t;try{t=await e.text()}catch{throw new l(`Couldn't read that file. Try again.`)}if(t.length>1e5)throw new l(c(t.length));return{name:e.name,size:e.size,lastModified:e.lastModified,html:t}}function d(e,t=`pasted.html`){if(e.length>1e5)throw new l(c(e.length));return{name:t,size:new Blob([e]).size,lastModified:Date.now(),html:e}}function f(e){if(!e.trim())return null;try{return d(e,`description.html`)}catch{return null}}var p=e(),m=[{id:`desktop`,label:`Máy Tính`,width:`100%`},{id:`tablet`,label:`Máy Tính Bảng`,width:`768px`},{id:`mobile`,label:`Điện Thoại`,width:`390px`}];function h({initialValue:e=null,onLoad:t,onClear:n}){let[r,i]=(0,a.useState)(e),[s,c]=(0,a.useState)(``),[d,f]=(0,a.useState)(!1),[h,v]=(0,a.useState)(!1),[y,b]=(0,a.useState)(`desktop`),[x,S]=(0,a.useState)(!1),[C,w]=(0,a.useState)(0),T=(0,a.useRef)(null),E=(0,a.useCallback)(async e=>{if(c(``),e)try{let n=await u(e);i(n),f(!1),w(e=>e+1),t?.(n)}catch(e){c(e instanceof l?e.message:`Couldn't read that file.`)}},[t]),D=()=>{i(null),c(``),f(!1),n?.()},O=e=>{e.preventDefault(),v(!1),E(e.dataTransfer.files?.[0])},k=e=>{E(e.target.files?.[0]),e.target.value=``},A=(0,a.useMemo)(()=>x?`allow-scripts allow-forms allow-popups`:``,[x]),j=m.find(e=>e.id===y)?.width??`100%`;return(0,p.jsxs)(`div`,{className:`hp-root`,children:[(0,p.jsx)(`style`,{children:_}),(0,p.jsxs)(`header`,{className:`hp-bar`,children:[(0,p.jsx)(`div`,{className:`hp-file`,children:r?(0,p.jsxs)(p.Fragment,{children:[(0,p.jsx)(`strong`,{title:r.name,children:r.name}),(0,p.jsx)(`span`,{children:g(r.size)})]}):(0,p.jsx)(`span`,{children:`Không có file`})}),(0,p.jsxs)(`div`,{className:`hp-count`,"aria-live":`polite`,children:[`HTML: `,r?.html.length??0,`/`,o]}),(0,p.jsx)(`div`,{className:`hp-group`,role:`group`,"aria-label":`Preview width`,children:m.map(e=>(0,p.jsx)(`button`,{type:`button`,className:`hp-btn`+(y===e.id?` is-on`:``),"aria-pressed":y===e.id,onClick:()=>b(e.id),children:e.label},e.id))}),(0,p.jsxs)(`label`,{className:`hp-check`,children:[(0,p.jsx)(`input`,{type:`checkbox`,checked:x,onChange:e=>S(e.target.checked)}),`Chạy script`]}),(0,p.jsx)(`button`,{type:`button`,className:`hp-btn`,disabled:!r,onClick:()=>w(e=>e+1),children:`Tải lại`}),(0,p.jsx)(`button`,{type:`button`,className:`hp-btn hp-primary`,onClick:()=>T.current?.click(),children:r?`Thay thế tệp`:`Chọn tệp`}),(0,p.jsx)(`button`,{type:`button`,className:`hp-btn`,disabled:!r,onClick:()=>f(!0),children:`Xóa`}),(0,p.jsx)(`input`,{ref:T,type:`file`,accept:`.html,.htm,text/html`,hidden:!0,onChange:k})]}),d&&r&&(0,p.jsxs)(`div`,{className:`hp-error`,role:`alert`,children:[`Xóa file này?`,(0,p.jsx)(`button`,{type:`button`,className:`hp-btn`,onClick:()=>f(!1),children:`Hủy`}),(0,p.jsx)(`button`,{type:`button`,className:`hp-btn hp-primary`,onClick:D,children:`Xóa`})]}),s&&(0,p.jsx)(`div`,{className:`hp-error`,role:`alert`,children:s}),(0,p.jsx)(`main`,{className:`hp-stage`+(h?` is-drag`:``),onDragOver:e=>{e.preventDefault(),v(!0)},onDragLeave:()=>v(!1),onDrop:O,children:r?(0,p.jsx)(`iframe`,{title:`Preview of ${r.name}`,className:`hp-frame`,style:{width:j},sandbox:A,srcDoc:r.html},`${C}-${x?`scripts`:`noscripts`}`):(0,p.jsxs)(`div`,{className:`hp-empty`,children:[(0,p.jsx)(`p`,{className:`hp-empty-title`,children:`Kéo thả tệp HTML`}),(0,p.jsx)(`p`,{children:`hoặc chọn một tệp từ máy tính của bạn để xem nó được hiển thị.`}),(0,p.jsx)(`button`,{type:`button`,className:`hp-btn hp-primary`,onClick:()=>T.current?.click(),children:`Chọn tệp`})]})})]})}function g(e){return e<1024?`${e} B`:e<1048576?`${(e/1024).toFixed(1)} KB`:`${(e/1024/1024).toFixed(1)} MB`}var _=`
.hp-root{display:flex;flex-direction:column;height:100vh;min-height:480px;
  font:14px/1.4 system-ui,-apple-system,"Segoe UI",sans-serif;color:#1d2433;background:#e9ecf1}
.hp-bar{display:flex;align-items:center;gap:12px;padding:10px 14px;background:#fff;
  border-bottom:1px solid #d5dae3;flex-wrap:wrap}
.hp-file{flex:1;min-width:140px;display:flex;gap:10px;align-items:baseline;overflow:hidden}
.hp-file strong{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.hp-file span{color:#6b7385;white-space:nowrap}
.hp-count{font-variant-numeric:tabular-nums;color:#4a5266;white-space:nowrap}
.hp-group{display:flex;border:1px solid #c6ccd8;border-radius:6px;overflow:hidden}
.hp-group .hp-btn{border:0;border-radius:0;border-right:1px solid #c6ccd8}
.hp-group .hp-btn:last-child{border-right:0}
.hp-btn{font:inherit;padding:6px 12px;border:1px solid #c6ccd8;border-radius:6px;
  background:#fff;color:inherit;cursor:pointer}
.hp-btn:hover:not(:disabled){background:#f2f4f8}
.hp-btn:disabled{opacity:.45;cursor:not-allowed}
.hp-btn.is-on{background:#1f3a5f;color:#fff}
.hp-primary{background:#1f3a5f;border-color:#1f3a5f;color:#fff}
.hp-primary:hover:not(:disabled){background:#2a4b7a}
.hp-btn:focus-visible,.hp-check input:focus-visible{outline:2px solid #3b7ddd;outline-offset:2px}
.hp-check{display:flex;align-items:center;gap:6px;cursor:pointer}
.hp-error{padding:8px 14px;background:#fdecec;color:#8a1c1c;border-bottom:1px solid #f3c3c3}
.hp-error .hp-btn{margin-left:8px}
.hp-stage{flex:1;display:flex;justify-content:center;overflow:auto;padding:16px;
  transition:background .15s}
.hp-stage.is-drag{background:#d8e4f6}
.hp-frame{height:100%;max-width:100%;border:1px solid #c6ccd8;border-radius:4px;background:#fff;
  box-shadow:0 1px 3px rgba(20,30,50,.12);transition:width .2s}
.hp-empty{align-self:center;text-align:center;max-width:340px;padding:32px;
  border:2px dashed #aab3c4;border-radius:10px;color:#4a5266}
.hp-empty p{margin:0 0 8px}
.hp-empty .hp-btn{margin-top:10px}
.hp-empty-title{font-size:18px;font-weight:600;color:#1d2433}
@media (prefers-reduced-motion:reduce){.hp-frame,.hp-stage{transition:none}}
`;export{r as i,f as n,i as r,h as t};
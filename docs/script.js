(() => {
  const button = document.getElementById('langToggle');
  const pairs = [
    ['NON-COMMERCIAL SOFTWARE PROJECT','非商業軟體開發專案'],
    ['About','關於'],['Architecture','架構'],['Features','功能'],['Tech Stack','技術'],['Roadmap','路線圖'],
    ['SOURCE CODE','原始碼'],['Follow the project as it grows.','一起看看這個專案如何持續成長。'],
    ['Built to learn. Built to ship.','一邊學習，一邊把作品做出來。']
  ];
  let zh=false;
  button?.addEventListener('click',()=>{
    zh=!zh;button.textContent=zh?'EN':'中文';document.documentElement.lang=zh?'zh-Hant':'en';
    const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);const nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);
    for(const n of nodes){let v=n.nodeValue;for(const [a,b] of pairs)v=v.split(zh?a:b).join(zh?b:a);n.nodeValue=v}
    document.title=zh?'Thunder_Community — 軟體開發專案':'Thunder_Community — Software Development Project';
  });
})();

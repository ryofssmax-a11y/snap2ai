// Snap2AI: ブラウザの右クリックメニューから Snap2AI（Windows のアプリ）に切り取りを頼む
const HOST = "com.ryo.snap2ai";

function setupMenus() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({ id: "snap2ai-capture", title: "Snap2AIで切り取って送る", contexts: ["all"] });
    chrome.contextMenus.create({ id: "snap2ai-last", title: "Snap2AIで切り取って直前のAIへ送る", contexts: ["all"] });
  });
}
chrome.runtime.onInstalled.addListener(setupMenus);
chrome.runtime.onStartup.addListener(setupMenus);

chrome.contextMenus.onClicked.addListener((info) => {
  const action = info.menuItemId === "snap2ai-last" ? "capturelast" : "capture";
  chrome.runtime.sendNativeMessage(HOST, { action }, () => {
    if (chrome.runtime.lastError) console.warn("Snap2AI:", chrome.runtime.lastError.message);
  });
});

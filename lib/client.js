// dsh-capybara-notify — browser half.
// 默认永久隐藏网页 GUI 里的宠物渲染（桌面宠物才是主角，API 不受影响）。
// 想恢复网页宠物：浏览器控制台执行
//   localStorage.setItem("dsh-capybara:gui-pet", "shown")
// 然后刷新；再执行 localStorage.removeItem("dsh-capybara:gui-pet") 后刷新可重新隐藏。
window.__ModuleLoader__.load({
  id: "dsh-capybara-notify",
  factory: () => {
    const module = { exports: {} };
    const exports = module.exports;

    const STYLE_ID = "dsh-capybara-style";

    function ensureStyle() {
      if (document.getElementById(STYLE_ID)) return;
      const style = document.createElement("style");
      style.id = STYLE_ID;
      style.textContent = "[data-dsh-pet-root] { display: none !important; }";
      document.head.appendChild(style);
    }

    function removeStyle() {
      const style = document.getElementById(STYLE_ID);
      if (style) style.remove();
    }

    exports.apply = () => {
      const sync = () => {
        try {
          const shown = localStorage.getItem("dsh-capybara:gui-pet") === "shown";
          if (shown) removeStyle();
          else ensureStyle();
        } catch {}
      };
      sync();
      const onStorage = () => sync();
      window.addEventListener("storage", onStorage);
      return () => {
        window.removeEventListener("storage", onStorage);
        removeStyle();
      };
    };

    return module.exports;
  },
});

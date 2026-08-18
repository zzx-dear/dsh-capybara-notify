// dsh-capybara-notify — browser half.
// 默认什么都不动。可选：在浏览器控制台/任意页面执行
//   localStorage.setItem("dsh-capybara:gui-pet", "hidden")
// 后刷新，即可隐藏网页 GUI 里的宠物渲染（桌面宠物用户的洁癖开关）。
window.__ModuleLoader__.load({
  id: "dsh-capybara-notify",
  factory: () => {
    const module = { exports: {} };
    const exports = module.exports;

    exports.apply = () => {
      let style = null;
      const sync = () => {
        try {
          const hidden = localStorage.getItem("dsh-capybara:gui-pet") === "hidden";
          if (hidden && !style) {
            style = document.createElement("style");
            style.id = "dsh-capybara-style";
            style.textContent = "[data-dsh-pet-root] { display: none !important; }";
            document.head.appendChild(style);
          } else if (!hidden && style) {
            style.remove();
            style = null;
          }
        } catch {}
      };
      sync();
      const onStorage = () => sync();
      window.addEventListener("storage", onStorage);
      return () => {
        window.removeEventListener("storage", onStorage);
        if (style) style.remove();
      };
    };

    return module.exports;
  },
});

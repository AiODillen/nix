# Theme gram (a Zed-based editor, app.liten.Gram) from the stylix base16 palette.
# Stylix has no zed/gram target, so we generate a Zed-schema theme JSON from
# config.lib.stylix.colors and pin gram to it. settings.jsonc is HM-managed here
# (this is a nix-dotfiles setup) — edit settings in nix, not gram's UI.
{ config, lib, ... }:
let
  c = config.lib.stylix.colors.withHashtag; # base00..base0F, "#rrggbb"
  appearance = if config.stylix.polarity == "light" then "light" else "dark";

  # base16 → Zed style. Standard base16 roles:
  # 00 bg · 01 lighter bg · 02 selection · 03 comments · 04 dark fg · 05 fg ·
  # 06 light fg · 07 lightest · 08 red · 09 orange · 0A yellow · 0B green ·
  # 0C cyan · 0D blue · 0E purple · 0F brown
  style = {
    border = c.base02;
    "border.variant" = c.base01;
    "border.focused" = c.base0D;
    "border.selected" = c.base0D;
    "border.transparent" = "#00000000";
    "border.disabled" = c.base01;
    "elevated_surface.background" = c.base01;
    "surface.background" = c.base01;
    background = c.base00;
    "element.background" = c.base01;
    "element.hover" = c.base02;
    "element.active" = c.base02;
    "element.selected" = c.base02;
    "element.disabled" = c.base01;
    "drop_target.background" = c.base02;
    "ghost_element.background" = "#00000000";
    "ghost_element.hover" = c.base01;
    "ghost_element.active" = c.base02;
    "ghost_element.selected" = c.base02;
    "ghost_element.disabled" = c.base01;
    text = c.base05;
    "text.muted" = c.base04;
    "text.placeholder" = c.base03;
    "text.disabled" = c.base03;
    "text.accent" = c.base0D;
    icon = c.base05;
    "icon.muted" = c.base04;
    "icon.disabled" = c.base03;
    "icon.placeholder" = c.base04;
    "icon.accent" = c.base0D;
    "status_bar.background" = c.base01;
    "title_bar.background" = c.base01;
    "title_bar.inactive_background" = c.base00;
    "toolbar.background" = c.base00;
    "tab_bar.background" = c.base01;
    "tab.inactive_background" = c.base01;
    "tab.active_background" = c.base00;
    "search.match_background" = c.base02;
    "panel.background" = c.base01;
    "panel.focused_border" = c.base0D;
    "pane.focused_border" = c.base0D;
    "scrollbar.thumb.background" = c.base02;
    "scrollbar.thumb.hover_background" = c.base03;
    "scrollbar.thumb.border" = c.base02;
    "scrollbar.track.background" = c.base00;
    "scrollbar.track.border" = c.base01;
    "editor.foreground" = c.base05;
    "editor.background" = c.base00;
    "editor.gutter.background" = c.base00;
    "editor.subheader.background" = c.base01;
    "editor.active_line.background" = c.base01;
    "editor.highlighted_line.background" = c.base01;
    "editor.line_number" = c.base03;
    "editor.active_line_number" = c.base05;
    "editor.invisible" = c.base03;
    "editor.wrap_guide" = c.base01;
    "editor.active_wrap_guide" = c.base02;
    "editor.document_highlight.read_background" = c.base02;
    "editor.document_highlight.write_background" = c.base03;
    "terminal.background" = c.base00;
    "terminal.foreground" = c.base05;
    "terminal.ansi.black" = c.base00;
    "terminal.ansi.red" = c.base08;
    "terminal.ansi.green" = c.base0B;
    "terminal.ansi.yellow" = c.base0A;
    "terminal.ansi.blue" = c.base0D;
    "terminal.ansi.magenta" = c.base0E;
    "terminal.ansi.cyan" = c.base0C;
    "terminal.ansi.white" = c.base05;
    "terminal.ansi.bright_black" = c.base03;
    "terminal.ansi.bright_red" = c.base08;
    "terminal.ansi.bright_green" = c.base0B;
    "terminal.ansi.bright_yellow" = c.base0A;
    "terminal.ansi.bright_blue" = c.base0D;
    "terminal.ansi.bright_magenta" = c.base0E;
    "terminal.ansi.bright_cyan" = c.base0C;
    "terminal.ansi.bright_white" = c.base07;
    "link_text.hover" = c.base0C;
    conflict = c.base09;
    created = c.base0B;
    deleted = c.base08;
    error = c.base08;
    warning = c.base0A;
    info = c.base0D;
    hint = c.base0C;
    modified = c.base0A;
    predictive = c.base03;
    renamed = c.base0D;
    success = c.base0B;
    unreachable = c.base04;
    players = [
      { cursor = c.base0D; background = c.base0D; selection = c.base02; }
    ];
    syntax = {
      keyword = { color = c.base0E; };
      operator = { color = c.base05; };
      punctuation = { color = c.base05; };
      comment = { color = c.base03; font_style = "italic"; };
      "comment.doc" = { color = c.base03; };
      string = { color = c.base0B; };
      "string.escape" = { color = c.base0C; };
      "string.regex" = { color = c.base0C; };
      "string.special" = { color = c.base0C; };
      number = { color = c.base09; };
      boolean = { color = c.base09; };
      constant = { color = c.base09; };
      variable = { color = c.base05; };
      "variable.special" = { color = c.base08; };
      property = { color = c.base08; };
      function = { color = c.base0D; };
      "function.method" = { color = c.base0D; };
      type = { color = c.base0A; };
      "type.builtin" = { color = c.base0A; };
      constructor = { color = c.base0D; };
      tag = { color = c.base08; };
      attribute = { color = c.base0A; };
      label = { color = c.base0D; };
      link_uri = { color = c.base0C; };
      link_text = { color = c.base09; };
      title = { color = c.base0D; };
      emphasis = { color = c.base0E; font_style = "italic"; };
      "emphasis.strong" = { color = c.base09; font_weight = 700; };
      predictive = { color = c.base03; };
      hint = { color = c.base04; };
    };
  };

  theme = {
    "$schema" = "https://zed.dev/schema/themes/v0.2.0.json";
    name = "Stylix";
    author = "stylix (base16)";
    themes = [
      ({ name = "Stylix"; inherit appearance style; })
    ];
  };
in
{
  xdg.configFile."gram/themes/stylix.json".text = builtins.toJSON theme;

  # settings.jsonc is plain JSON-compatible; pin theme to "Stylix" (string form
  # = always this theme, ignores system light/dark). Other keys mirror the
  # previous hand-written settings.
  xdg.configFile."gram/settings.jsonc".text = builtins.toJSON {
    git_panel = { tree_view = true; dock = "right"; };
    ui_font_size = 14;
    buffer_font_size = 14;
    theme = "Stylix";
  };
}

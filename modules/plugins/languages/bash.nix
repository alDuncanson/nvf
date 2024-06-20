{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (builtins) attrNames;
  inherit (lib.options) mkOption mkEnableOption literalExpression;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.lists) isList;
  inherit (lib.types) enum either package listOf str bool;
  inherit (lib.nvim.languages) diagnosticsToLua;
  inherit (lib.nvim.types) diagnostics mkGrammarOption;
  inherit (lib.nvim.lua) expToLua;

  cfg = config.vim.languages.bash;

  defaultServer = "bash-ls";
  servers = {
    bash-ls = {
      package = pkgs.bash-language-server;
      lspConfig = ''
        lspconfig.bashls.setup{
          capabilities = capabilities;
          on_attach = default_on_attach;
          cmd = ${
          if isList cfg.lsp.package
          then expToLua cfg.lsp.package
          else ''{"${cfg.lsp.package}/bin/bash-language-server",  "start"}''
        };
        }
      '';
    };
  };

  defaultFormat = "shfmt";
  formats = {
    shfmt = {
      package = pkgs.shfmt;
      nullConfig = ''
        table.insert(
          ls_sources,
          null_ls.builtins.formatting.shfmt.with({
            command = "${pkgs.shfmt}/bin/shfmt",
          })
        )
      '';
    };
  };

  defaultDiagnosticsProvider = ["shellcheck"];
  diagnosticsProviders = {
    shellcheck = {
      package = pkgs.shellcheck;
      nullConfig = pkg: ''
        table.insert(
          ls_sources,
          null_ls.builtins.diagnostics.shellcheck.with({
            command = "${pkg}/bin/shellcheck",
            diagnostics_format = "#{m} [#{c}]"
          })
        )
      '';
    };
  };
in {
  options.vim.languages.bash = {
    enable = mkEnableOption "Bash language support";

    treesitter = {
      enable = mkEnableOption "Bash treesitter" // {default = config.vim.languages.enableTreesitter;};
      package = mkGrammarOption pkgs "bash";
    };

    lsp = {
      enable = mkEnableOption "Enable Bash LSP support" // {default = config.vim.languages.enableLSP;};

      server = mkOption {
        description = "Bash LSP server to use";
        type = enum (attrNames servers);
        default = defaultServer;
      };

      package = mkOption {
        description = "bash-language-server package, or the command to run as a list of strings";
        example = literalExpression ''[lib.getExe pkgs.nodePackages.bash-language-server "start"]'';
        type = either package (listOf str);
        default = pkgs.bash-language-server;
      };
    };

    format = {
      enable = mkOption {
        description = "Enable Bash formatting";
        type = bool;
        default = config.vim.languages.enableFormat;
      };
      type = mkOption {
        description = "Bash formatter to use";
        type = enum (attrNames formats);
        default = defaultFormat;
      };

      package = mkOption {
        description = "Bash formatter package";
        type = package;
        default = formats.${cfg.format.type}.package;
      };
    };

    extraDiagnostics = {
      enable = mkEnableOption "extra Bash diagnostics" // {default = config.vim.languages.enableExtraDiagnostics;};
      types = diagnostics {
        langDesc = "Bash";
        inherit diagnosticsProviders;
        inherit defaultDiagnosticsProvider;
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.treesitter.enable {
      vim.treesitter.enable = true;
      vim.treesitter.grammars = [cfg.treesitter.package];
    })

    (mkIf cfg.lsp.enable {
      vim.lsp.lspconfig.enable = true;
      vim.lsp.lspconfig.sources.bash-lsp = servers.${cfg.lsp.server}.lspConfig;
    })

    (mkIf cfg.format.enable {
      vim.lsp.null-ls.enable = true;
      vim.lsp.null-ls.sources.bash-format = formats.${cfg.format.type}.nullConfig;
    })

    (mkIf cfg.extraDiagnostics.enable {
      vim.lsp.null-ls.enable = true;
      vim.lsp.null-ls.sources = diagnosticsToLua {
        lang = "bash";
        config = cfg.extraDiagnostics.types;
        inherit diagnosticsProviders;
      };
    })
  ]);
}

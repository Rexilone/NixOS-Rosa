{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    keymaps = [
      # Открыть Neo-tree по нажатию Ctrl+n
      {
        mode = "n";
        key = "<C-n>";
        action = ":Neotree toggle<CR>";
        options.silent = true;
      }

      # Быстрое сохранение через Space + w
      {
        mode = "n";
        key = "<leader>w";
        action = ":w<CR>";
        options.desc = "Save file";
      }
    ];

    plugins = {
      vim-devicons.enable = true;
      neo-tree.enable = true;
      lightline = {
        enable = true;
	settings = {
	  colorscheme = "Tomorrow_Night_Bright";
	  separator = {
            left = "";
            right = "";
          };
          subseparator = {
            left = "";
            right = "";
          };
 	    # Настройка строк состояния (активной и неактивной)
          active = {
            left = [
              [ "mode" "paste" ]
              [ "readonly" "filename" "modified" "method" ]
            ];
            right = [
              [ "lineinfo" ]
              [ "percent" ]
              [ "fileformat" "fileencoding" "filetype" ]
            ];
          };
	    };
      };
    };
  };
}

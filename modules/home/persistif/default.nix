{ lib, inputs, config, osConfig, pkgs, ... }:
let
  # we automatically activate if the system persist option is activated, no sense having them differ
  osCfg = osConfig.impermanence;
  # the type of the forwarded impermanence option, extracted from the impermanence module
  persistOptionType = (pkgs.callPackage inputs.impermanence.nixosModules.home-manager.impermanence {
    config.home.impermanence.persistif = config.persistif;
  }).options.home.persistence.type.nestedTypes.elemType;
in
{
  imports = [ inputs.impermanence.nixosModules.home-manager.impermanence ];
  options = {
    # this is where modules can set their persistence dirs and files, the option is
    # is forwarded to the impermanence module
    persistif = lib.mkOption {
      default = { };
      type = persistOptionType;
    };
  };
  config = lib.mkIf (osCfg.enable) {
    # forward the peristif config to the impermanence config
    home.persistence."" = config.persistif;

    # since we overwrite the storage path here, we don't need to name it above
    persistif.persistentStoragePath = "${osCfg.persistPath}/home/${config.snowfallorg.user.name}";

    # this is needed to allow sudo to access the mounts
    persistif.allowOther = true;
  };
}

# lib.mkOption {
#       default = { };
#       type = with lib.types;
#         submodule ({ name, ... }: {
#           options =
#             {
#               directories = lib.mkOption {
#                 type = with types; listOf (either str (submodule {
#                   options = {
#                     directory = lib.mkOption {
#                       type = str;
#                       default = null;
#                       description = "The directory path to be linked.";
#                     };
#                     method = lib.mkOption {
#                       type = types.enum [ "bindfs" "symlink" ];
#                       default = "bindfs";
#                       description = ''
#                         The linking method that should be used for this
#                         directory. bindfs is the default and works for most use
#                         cases, however some programs may behave better with
#                         symlinks.
#                       '';
#                     };
#                   };
#                 }));
#                 default = [ ];
#                 example = [
#                   "Downloads"
#                   "Music"
#                   "Pictures"
#                   "Documents"
#                   "Videos"
#                   "VirtualBox VMs"
#                   ".gnupg"
#                   ".ssh"
#                   ".local/share/keyrings"
#                   ".local/share/direnv"
#                   {
#                     directory = ".local/share/Steam";
#                     method = "symlink";
#                   }
#                 ];
#                 description = ''
#                   A list of directories in your home directory that
#                   you want to link to persistent storage. You may optionally
#                   specify the linking method each directory should use.
#                 '';
#               };

#               files = lib.mkOption {
#                 type = with types; listOf str;
#                 default = [ ];
#                 example = [
#                   ".screenrc"
#                 ];
#                 description = ''
#                   A list of files in your home directory you want to
#                   link to persistent storage.
#                 '';
#               };

#               allowOther = lib.mkOption {
#                 type = with types; nullOr bool;
#                 default = null;
#                 example = true;
#                 apply = x:
#                   if x == null then
#                     warn ''
#                       home.persistence."${name}".allowOther not set; assuming 'false'.
#                       See https://github.com/nix-community/impermanence#home-manager for more info.
#                     ''
#                       false
#                   else
#                     x;
#                 description = ''
#                   Whether to allow other users, such as
#                   <literal>root</literal>, access to files through the
#                   bind mounted directories listed in
#                   <literal>directories</literal>. Requires the NixOS
#                   configuration parameter
#                   <literal>programs.fuse.userAllowOther</literal> to
#                   be <literal>true</literal>.
#                 '';
#               };

#               removePrefixDirectory = lib.mkOption {
#                 type = types.bool;
#                 default = false;
#                 example = true;
#                 description = ''
#                   Note: This is mainly useful if you have a dotfiles
#                   repo structured for use with GNU Stow; if you don't,
#                   you can likely ignore it.

#                   Whether to remove the first directory when linking
#                   or mounting; e.g. for the path
#                   <literal>"screen/.screenrc"</literal>, the
#                   <literal>screen/</literal> is ignored for the path
#                   linked to in your home directory.
#                 '';
#               };
#             };
#         });
#       description = ''
#         A set of persistent storage location submodules listing the
#         files and directories to link to their respective persistent
#         storage location.

#         Each attribute name should be the path relative to the user's
#         home directory.

#         For detailed usage, check the <link
#         xlink:href="https://github.com/nix-community/impermanence">documentation</link>.
#       '';
#       example = lib.literalExpression ''
#         {
#           "/persistent/home/talyz" = {
#             directories = [
#               "Downloads"
#               "Music"
#               "Pictures"
#               "Documents"
#               "Videos"
#               "VirtualBox VMs"
#               ".gnupg"
#               ".ssh"
#               ".nixops"
#               ".local/share/keyrings"
#               ".local/share/direnv"
#               {
#                 directory = ".local/share/Steam";
#                 method = "symlink";
#               }
#             ];
#             files = [
#               ".screenrc"
#             ];
#             allowOther = true;
#           };
#         }
#       '';
#     };

#!/usr/bin/env bash

ui_users_keys_menu() {
  local choice username key confirm add_to_sudo home key_type key_data key_status
  while true; do
    printf '\n%s\n' "$(ui_text '用户与 SSH 密钥' 'Users and SSH keys')"
    printf '%s\n' \
      "1) $(ui_text '列出用户和 sudo 组' 'List users and sudo group')" \
      "2) $(ui_text '创建普通用户' 'Create a normal user')" \
      "3) $(ui_text '为用户添加 SSH 公钥' 'Add an SSH public key')" \
      "4) $(ui_text '启用 root 公钥登录、关闭 root 密码登录' 'Disable root password login after key check')" \
      "0) $(ui_text '返回主菜单' 'Back to main menu')"
    read -r -p '> ' choice || return
    case "$choice" in
      1)
        printf '%s\n' "$(ui_text '可登录用户：' 'Login-capable users:')"
        awk -F: '$7 !~ /(nologin|false)$/ {printf "%-20s uid=%s home=%s shell=%s\n", $1, $3, $6, $7}' /etc/passwd
        printf '%s\n' 'sudo:'; getent group sudo 2>/dev/null || true
        ui_pause
        ;;
      2)
        if ! root_required || ! have useradd; then continue; fi
        read -r -p "$(ui_text '输入新用户名：' 'New username: ')" username
        case "$username" in ''|*[!a-zA-Z0-9_-]*) printf '%s\n' "$(ui_text '用户名格式无效。' 'Invalid username.')"; continue ;; esac
        if id "$username" >/dev/null 2>&1; then printf '%s\n' "$(ui_text '用户已存在。' 'User already exists.')"; continue; fi
        read -r -p "$(ui_text '是否加入 sudo 组？输入 y 或 n：' 'Add to sudo group? Type y or n: ')" confirm
        case "$confirm" in y|Y) add_to_sudo=yes ;; n|N) add_to_sudo=no ;; *) printf '%s\n' "$(ui_text '请输入 y 或 n。' 'Please enter y or n.')"; continue ;; esac
        read -r -p "$(ui_text '确认创建？输入 y/n：' 'Confirm creation? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        if useradd -m -s /bin/bash "$username"; then
          if [ "$add_to_sudo" = yes ]; then
            if usermod -aG sudo "$username"; then
              printf '%s\n' "$(ui_text '用户已创建并加入 sudo 组。' 'User created and added to the sudo group.')"
            else
              printf '%s\n' "$(ui_text '用户已创建，但加入 sudo 组失败。' 'User created, but adding to sudo failed.')"
            fi
          else
            printf '%s\n' "$(ui_text '用户已创建；请使用 passwd 或 SSH 公钥设置登录方式。' 'User created; configure login with passwd or an SSH public key.')"
          fi
        else
          printf '%s\n' "$(ui_text '创建用户失败。' 'Failed to create user.')"
        fi
        ui_pause
        ;;
      3)
        if ! root_required; then continue; fi
        read -r -p "$(ui_text '目标用户名：' 'Target username: ')" username
        if ! id -- "$username" >/dev/null 2>&1; then printf '%s\n' "$(ui_text '用户不存在。' 'User does not exist.')"; continue; fi
        read -r -p "$(ui_text '粘贴一行 SSH 公钥：' 'Paste one SSH public key line: ')" key
        read -r key_type key_data _ <<< "$key"
        case "$key_type" in ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com) ;; *) printf '%s\n' "$(ui_text '不支持或无效的公钥类型。' 'Unsupported or invalid public key type.')"; continue ;; esac
        if [ -z "$key_data" ] || ! [[ "$key_data" =~ ^[A-Za-z0-9+/]+={0,2}$ ]]; then printf '%s\n' "$(ui_text '公钥数据格式无效。' 'Invalid public key data.')"; continue; fi
        read -r -p "$(ui_text '确认写入？输入 y/n：' 'Confirm write? Enter y/n: ')" confirm
        is_yes "$confirm" || { say cancel; continue; }
        home=$(getent passwd "$username" | cut -d: -f6)
        if [ -z "$home" ] || [ ! -d "$home" ]; then printf '%s\n' "$(ui_text '用户主目录不存在。' 'The user home directory does not exist.')"; continue; fi
        append_authorized_key "$username" "$key"
        key_status=$?
        if [ "$key_status" -eq 0 ]; then
          printf '%s\n' "$(ui_text '公钥已写入。' 'Public key added.')"
        elif [ "$key_status" -eq 2 ]; then
          printf '%s\n' "$(ui_text '拒绝写入：.ssh 或 authorized_keys 是符号链接。' 'Refusing to write: .ssh or authorized_keys is a symbolic link.')"
        else
          printf '%s\n' "$(ui_text '写入公钥失败；请检查主目录权限。' 'Failed to write the key; check home directory permissions.')"
        fi
        ui_pause
        ;;
      4)
        harden_ssh_root_password
        ui_pause
        ;;
      0) return ;;
      *) printf '%s\n' "$(ui_text '无效选择。' 'Invalid choice.')" ;;
    esac
  done
}

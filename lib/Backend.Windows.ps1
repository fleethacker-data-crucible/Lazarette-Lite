#requires -Version 5.1
# =============================================================================
# The real credential backend: Windows Credential Manager, generic credentials.
# The only place Lite touches Windows. The C# ships here as source (not as a
# .cs file or a DLL) so the Authenticode signature on this script covers it,
# and it is compiled in memory with Add-Type.
#
# A backend is an object with four script-block members. Tests swap in a fake.
#   Enumerate $filter                     -> items (no secrets), filter is 'prefix*'
#   Read $target                          -> item with .Secret, or $null
#   Write $target $user $comment $secret  -> throws on failure
#   Delete $target                        -> $true if it existed
# An item has: Target, UserName, Comment, LastWritten, SecretBytes (and Secret on Read).
# =============================================================================

function Initialize-LiteNative {
    if ('LiteCredNative' -as [type]) { return }
    if ($env:OS -ne 'Windows_NT') { throw 'Lazarette Lite needs Windows Credential Manager and only runs on Windows.' }
    $src = @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class LiteCredNative
{
    const int CRED_TYPE_GENERIC = 1;
    const int CRED_PERSIST_LOCAL_MACHINE = 2;   // never roams; matches Lazarette's bridge
    const int ERROR_NOT_FOUND = 1168;

    public sealed class Item
    {
        public string Target;
        public string UserName;
        public string Comment;
        public DateTime LastWritten;
        public int SecretBytes;
        public string Secret;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct CREDENTIAL
    {
        public int Flags; public int Type; public string TargetName; public string Comment; public long LastWritten;
        public int CredentialBlobSize; public IntPtr CredentialBlob; public int Persist; public int AttributeCount;
        public IntPtr Attributes; public string TargetAlias; public string UserName;
    }

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool CredWrite(ref CREDENTIAL c, uint flags);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool CredRead(string target, int type, int reserved, out IntPtr cred);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool CredDelete(string target, int type, int flags);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool CredEnumerate(string filter, int flags, out int count, out IntPtr creds);
    [DllImport("advapi32.dll", SetLastError = true)] static extern void CredFree(IntPtr buffer);

    static Item ToItem(CREDENTIAL c, bool withSecret)
    {
        Item it = new Item();
        it.Target = c.TargetName;
        it.UserName = c.UserName;
        it.Comment = c.Comment;
        it.LastWritten = c.LastWritten > 0 ? DateTime.FromFileTimeUtc(c.LastWritten) : DateTime.MinValue;
        it.SecretBytes = c.CredentialBlobSize;
        if (withSecret)
        {
            if (c.CredentialBlobSize > 0 && c.CredentialBlob != IntPtr.Zero)
            {
                byte[] b = new byte[c.CredentialBlobSize];
                Marshal.Copy(c.CredentialBlob, b, 0, b.Length);
                it.Secret = Encoding.Unicode.GetString(b);
                Array.Clear(b, 0, b.Length);
            }
            else { it.Secret = ""; }
        }
        return it;
    }

    // Names and metadata only: the blob is never copied out of the Windows buffer.
    public static Item[] Enumerate(string filter)
    {
        int count; IntPtr ptr;
        if (!CredEnumerate(filter, 0, out count, out ptr))
        {
            int err = Marshal.GetLastWin32Error();
            if (err == ERROR_NOT_FOUND) return new Item[0];
            throw new Win32Exception(err);
        }
        try
        {
            List<Item> list = new List<Item>();
            for (int i = 0; i < count; i++)
            {
                IntPtr cp = Marshal.ReadIntPtr(ptr, i * IntPtr.Size);
                if (cp == IntPtr.Zero) continue;
                CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(cp, typeof(CREDENTIAL));
                if (c.Type == CRED_TYPE_GENERIC) list.Add(ToItem(c, false));
            }
            return list.ToArray();
        }
        finally { CredFree(ptr); }
    }

    public static Item Read(string target)
    {
        IntPtr ptr;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr))
        {
            int err = Marshal.GetLastWin32Error();
            if (err == ERROR_NOT_FOUND) return null;
            throw new Win32Exception(err);
        }
        try { return ToItem((CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL)), true); }
        finally { CredFree(ptr); }
    }

    public static void Write(string target, string userName, string comment, string secret)
    {
        byte[] bytes = Encoding.Unicode.GetBytes(secret ?? "");
        IntPtr blob = IntPtr.Zero;
        try
        {
            if (bytes.Length > 0)
            {
                blob = Marshal.AllocHGlobal(bytes.Length);
                Marshal.Copy(bytes, 0, blob, bytes.Length);
            }
            CREDENTIAL c = new CREDENTIAL();
            c.Type = CRED_TYPE_GENERIC;
            c.TargetName = target;
            c.UserName = userName;
            c.Comment = comment;
            c.CredentialBlobSize = bytes.Length;
            c.CredentialBlob = blob;
            c.Persist = CRED_PERSIST_LOCAL_MACHINE;
            if (!CredWrite(ref c, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        finally
        {
            if (blob != IntPtr.Zero)
            {
                Marshal.Copy(new byte[bytes.Length], 0, blob, bytes.Length);
                Marshal.FreeHGlobal(blob);
            }
            Array.Clear(bytes, 0, bytes.Length);
        }
    }

    public static bool Delete(string target)
    {
        if (CredDelete(target, CRED_TYPE_GENERIC, 0)) return true;
        int err = Marshal.GetLastWin32Error();
        if (err == ERROR_NOT_FOUND) return false;
        throw new Win32Exception(err);
    }
}
'@
    Add-Type -TypeDefinition $src -ErrorAction Stop
}

function New-LiteWindowsBackend {
    Initialize-LiteNative
    [pscustomobject]@{
        Name      = 'windows-credential-manager'
        Enumerate = { param($Filter) @([LiteCredNative]::Enumerate($Filter)) }
        Read      = { param($Target) [LiteCredNative]::Read($Target) }
        Write     = { param($Target, $UserName, $Comment, $Secret) [LiteCredNative]::Write($Target, $UserName, $Comment, $Secret) }
        Delete    = { param($Target) [LiteCredNative]::Delete($Target) }
    }
}

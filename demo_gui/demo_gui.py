import tkinter as tk
import urllib.request
import json

URL = "http://10.35.6.174:3000"
PID = "printer1"


def send():
    uid = uid_entry.get().strip()
    message = message_text.get("1.0", "end-1c").strip()

    if not uid or not message:
        print("Missing input: please fill in both fields.")
        return
    
    if image_var.get():
        message += "<IMAGE>"

    payload = json.dumps({"uid": uid, "message": message}).encode("utf-8")
    req = urllib.request.Request(
        f"{URL}/send?pid={PID}",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read().decode("utf-8", errors="replace")
            print(f"Status: {resp.status}")
            print(body)
    except Exception as e:
        print(f"Request failed: {e}")

    uid_entry.delete(0, "end")
    message_text.delete("1.0", "end")


root = tk.Tk()
root.title("Printimate Demo")
root.geometry("400x300")
 
tk.Label(root, text="Name:").grid(row=0, column=0, padx=10, pady=10, sticky="ne")
uid_entry = tk.Entry(root, width=30)
uid_entry.grid(row=0, column=1, padx=10, pady=10, sticky="w")
 
tk.Label(root, text="Message:").grid(row=1, column=0, padx=10, pady=10, sticky="ne")
message_text = tk.Text(root, width=32, height=8)
message_text.grid(row=1, column=1, padx=10, pady=10, sticky="w")
 
image_var = tk.BooleanVar(value=False)
tk.Checkbutton(root, text="Send Image", variable=image_var).grid(
    row=2, column=1, padx=10, sticky="w"
)
 
tk.Button(root, text="Send", width=12, command=send).grid(
    row=3, column=0, columnspan=2, pady=10
)
 
root.mainloop()
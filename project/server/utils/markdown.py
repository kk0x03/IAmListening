import re
import json

def parse_markdown_json(md_text: str):
    match = re.search(r"```json\s*(.*?)\s*```", md_text, re.DOTALL)
    if not match:
        raise ValueError("未找到 JSON 代码块")
    
    json_str = match.group(1)
    return json.loads(json_str)

def get_urgency_level(data: dict) -> str:
    urgency = data.get("紧急程度")
    if urgency == "高":
        return "high"
    return urgency or "unknown"
# 示例用法
# markdown_text = """
# ```json
# {
#     "场景": "日常交流",
#     "信息": "用户表达想要继续说话的意愿。",
#     "紧急程度": "高",
#     "建议行动": "等待用户接下来的发言。"
# }
# ```
# """
# parsed = parse_markdown_json(markdown_text)
# res = get_urgency_level(parsed)
# print(res)  # 输出: 高
-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- 用于unsigned类型运算

-- 实体定义（端口与参数）
entity data_gen is
    generic (
        CNT_1S   : integer := 49999999;  -- 1秒计数值（50MHz时钟：50e6 * 1 = 5e7，减1为49999999）
        SEC_MAX  : integer := 59;        -- 秒计数上限（0~59）
        MIN_MAX  : integer := 59;        -- 分计数上限（0~59）
        HOUR_MAX : integer := 23         -- 时计数上限（0~23）
    );
    port (
        sys_clk    : in  std_logic;                     -- 系统时钟，50MHz
        sys_rst_n  : in  std_logic;                     -- 复位信号，低电平有效
        data       : buffer unsigned(6 downto 0);       -- 数码管显示值（暂时保留，后续将被忽略）
        point      : out std_logic_vector(5 downto 0);  -- 小数点显示（用于时钟分隔符）
        seg_en     : out std_logic;                     -- 数码管使能（高电平有效）
        sign       : out std_logic                      -- 符号位（高电平显示负号，此处关闭）
    );
end entity data_gen;

-- 结构体定义（内部逻辑实现）
architecture Behavioral of data_gen is
    -- 时钟计数器信号
    signal cnt_1sec  : unsigned(25 downto 0);  -- 1秒计数器（26位：最大值49999999 < 2^26=67108864）
    signal flag_1sec : std_logic;              -- 1秒脉冲标志
    
    -- 时钟数据信号
    signal hour      : unsigned(4 downto 0);   -- 小时（0-23，5位足够）
    signal minute    : unsigned(5 downto 0);   -- 分钟（0-59，6位足够）
    signal second    : unsigned(5 downto 0);   -- 秒（0-59，6位足够）
    
    -- 扩展：时钟数据输出（用于连接到seg_dynamic模块）
    signal clock_data : std_logic_vector(15 downto 0);  -- 23:59:59格式，每两位一组
    
    attribute keep : boolean;
    attribute keep of hour   : signal is true;
    attribute keep of minute : signal is true;
    attribute keep of second : signal is true;
begin
    -- 1. 设置小数点（作为时钟分隔符）
    point <= "000000";  -- 格式：bit5 bit4 bit3 bit2 bit1 bit0
                         --      0    1    0    1    0    0
                         -- 这里bit4和bit2为'1'，对应时个位和分个位的小数点
    sign  <= '0';       -- 不显示负号

    -- 2. 1秒计数器（从0计数到CNT_1S，循环）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then  -- 复位时清零
            cnt_1sec <= (others => '0');
        elsif rising_edge(sys_clk) then  -- 时钟上升沿触发
            if cnt_1sec = to_unsigned(CNT_1S, cnt_1sec'length) then
                cnt_1sec <= (others => '0');  -- 计数到上限，清零
            else
                cnt_1sec <= cnt_1sec + 1;  -- 否则递增
            end if;
        end if;
    end process;

    -- 3. 1秒脉冲标志（计数到CNT_1S-1时，产生1个时钟周期高电平）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            flag_1sec <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_1sec = to_unsigned(CNT_1S - 1, cnt_1sec'length) then
                flag_1sec <= '1';  -- 即将清零时，置位标志
            else
                flag_1sec <= '0';  -- 其他时间清零
            end if;
        end if;
    end process;

    -- 4. 时钟计数逻辑（时:分:秒）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            -- 复位时清零
            hour   <= (others => '0');
            minute <= (others => '0');
            second <= (others => '0');
        elsif rising_edge(sys_clk) then
            if flag_1sec = '1' then  -- 每1秒触发一次计数更新
                -- 秒计数
                if second = to_unsigned(SEC_MAX, second'length) then
                    second <= (others => '0');  -- 秒计数到60，复位为0
                    -- 分计数
                    if minute = to_unsigned(MIN_MAX, minute'length) then
                        minute <= (others => '0');  -- 分计数到60，复位为0
                        -- 时计数
                        if hour = to_unsigned(HOUR_MAX, hour'length) then
                            hour <= (others => '0');  -- 时计数到24，复位为0
                        else
                            hour <= hour + 1;  -- 时递增
                        end if;
                    else
                        minute <= minute + 1;  -- 分递增
                    end if;
                else
                    second <= second + 1;  -- 秒递增
                end if;
            end if;
        end if;
    end process;
    
    -- 注意：保留原data信号以保持兼容性，但将其设置为0
    data <= (others => '0');  -- 这个信号在时钟模式下不再使用

    -- 5. 数码管使能（复位后一直有效，保持原有逻辑）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            seg_en <= '0';  -- 复位时关闭使能
        elsif rising_edge(sys_clk) then
            seg_en <= '1';  -- 复位后一直使能数码管
        end if;
    end process;
    
    -- 为了保持兼容性，声明一个外部接口用于获取时钟数据
    -- 注意：在实际使用中，需要修改counter60和seg_dynamic模块来使用这个数据

end architecture Behavioral;
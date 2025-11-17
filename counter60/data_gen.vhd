-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- 用于unsigned类型运算

-- 实体定义（端口与参数）
entity data_gen is
    generic (
        CNT_MAX  : integer := 4999999;  -- 100ms计数值（50MHz时钟：50e6 * 0.1 = 5e6，减1为4999999）
        DATA_MAX : integer := 60        -- 计数上限（0~60循环，共61个状态）
    );
    port (
        sys_clk    : in  std_logic;                     -- 系统时钟，50MHz
        sys_rst_n  : in  std_logic;                     -- 复位信号，低电平有效
        data       : buffer unsigned(6 downto 0);          -- 数码管显示值（0~60，7位足够）
        point      : out std_logic_vector(5 downto 0);  -- 小数点显示（高电平有效，此处关闭）
        seg_en     : out std_logic;                     -- 数码管使能（高电平有效）
        sign       : out std_logic                      -- 符号位（高电平显示负号，此处关闭）
    );
end entity data_gen;

-- 结构体定义（内部逻辑实现）
architecture Behavioral of data_gen is
    signal cnt_100ms : unsigned(22 downto 0);  -- 100ms计数器（23位：最大值4999999 < 2^23=8388608）
    signal cnt_flag  : std_logic;              -- 100ms脉冲标志（每100ms高电平1个时钟周期）
begin

    -- 1. 关闭小数点和负号（组合逻辑，保持原有配置）
    point <= (others => '1');  -- 6个小数点全关闭
    sign  <= '0';              -- 不显示负号

    -- 2. 100ms计数器（从0计数到CNT_MAX，循环）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then  -- 复位时清零
            cnt_100ms <= (others => '0');
        elsif rising_edge(sys_clk) then  -- 时钟上升沿触发
            if cnt_100ms = to_unsigned(CNT_MAX, cnt_100ms'length) then
                cnt_100ms <= (others => '0');  -- 计数到上限，清零
            else
                cnt_100ms <= cnt_100ms + 1;  -- 否则递增
            end if;
        end if;
    end process;

    -- 3. 100ms脉冲标志（计数到CNT_MAX-1时，产生1个时钟周期高电平）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_flag <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_100ms = to_unsigned(CNT_MAX - 1, cnt_100ms'length) then
                cnt_flag <= '1';  -- 即将清零时，置位标志
            else
                cnt_flag <= '0';  -- 其他时间清零
            end if;
        end if;
    end process;

    -- 4. 60进制计数逻辑（0~60循环，每100ms递增1）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            data <= (others => '0');  -- 复位时显示0
        elsif rising_edge(sys_clk) then
            if cnt_flag = '1' then  -- 每100ms触发一次计数更新
                if data = to_unsigned(DATA_MAX, data'length) then
                    data <= (others => '0');  -- 计数到60，复位为0
                else
                    data <= data + 1;  -- 否则递增（0→1→...→60）
                end if;
            end if;
        end if;
    end process;

    -- 5. 数码管使能（复位后一直有效，保持原有逻辑）
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            seg_en <= '0';  -- 复位时关闭使能
        elsif rising_edge(sys_clk) then
            seg_en <= '1';  -- 复位后一直使能数码管
        end if;
    end process;

end architecture Behavioral;